-- FPB Store package management. Operations work outside the UI for testing.
local C
if type(package) == "table" and type(require) == "function" then
  C = require("apps.fpbstore.catalog")
else
  C = dofile("/apps/fpbstore/catalog.lua")
end
local M = { catalog = C, REF = "main", BASE = "https://raw.githubusercontent.com/fpbcraft/cc-scripts/" }
local function ensure(path)
  if not fs.exists(path) then
    fs.makeDir(path)
  end
end
local function fetch(url)
  assert(http and http.get, "HTTP must be enabled")
  -- Bust intermediary HTTP caches so versions and installers reflect main.
  local separator = url:find("?", 1, true) and "&" or "?"
  local nonce = os.epoch and os.epoch("utc") or math.floor(os.clock() * 1000)
  local response, err = http.get(url .. separator .. "fpbstore_cb=" .. tostring(nonce), nil, true)
  assert(response, "Download failed: " .. tostring(err))
  local status = response.getResponseCode and response.getResponseCode() or 200
  local data = response.readAll()
  response.close()
  assert(status == 200 and type(data) == "string" and #data > 20, "HTTP " .. tostring(status) .. " from " .. url)
  return data
end
local function write(path, text)
  ensure(fs.getDir(path))
  local h, err = fs.open(path, "w")
  assert(h, err or ("Unable to write " .. path))
  h.write(text)
  h.close()
end
function M.get(id)
  for _, app in ipairs(C.apps) do
    if app.id == id then
      return app
    end
  end
  return nil
end
function M.installRoot(app)
  local h = fs.open("/apps/fpbstore/installed/" .. app.id .. ".dat", "r")
  if h then
    local ok, marker = pcall(textutils.unserialize, h.readAll())
    h.close()
    if ok and type(marker) == "table" and type(marker.root) == "string" then
      return marker.root
    end
  end
  return app.root
end
function M.installed(app)
  local entry = M.installRoot(app) .. app.entry:sub(#app.root + 1)
  return fs.exists(entry) and not fs.isDir(entry)
end

local PREF_PATH = "/apps/fpbstore/preferences.dat"
function M.preferences()
  local prefs = { display = "auto", opusStore = true, opusApps = true, launchTargets = {}, opusShortcuts = {} }
  local h = fs.open(PREF_PATH, "r")
  if h then
    local ok, data = pcall(textutils.unserialize, h.readAll())
    h.close()
    if ok and type(data) == "table" then
      if data.display == "auto" or data.display == "term" or data.display == "monitor" then
        prefs.display = data.display
      end
      if type(data.opusStore) == "boolean" then
        prefs.opusStore = data.opusStore
      end
      if type(data.opusApps) == "boolean" then
        prefs.opusApps = data.opusApps
      end
      if type(data.opusShortcuts) == "table" then
        for id, enabled in pairs(data.opusShortcuts) do
          if type(id) == "string" and type(enabled) == "boolean" then
            prefs.opusShortcuts[id] = enabled
          end
        end
      end
      if type(data.launchTargets) == "table" then
        for id, target in pairs(data.launchTargets) do
          if target == "term" or target == "monitor" or target == "ask" then
            prefs.launchTargets[id] = target
          end
        end
      end
    end
  end
  return prefs
end
function M.savePreferences(prefs)
  assert(prefs.display == "auto" or prefs.display == "term" or prefs.display == "monitor")
  ensure("/apps/fpbstore")
  write(PREF_PATH, textutils.serialize(prefs))
  M.syncOpus()
end
function M.setLaunchTarget(app, target)
  assert(app and M.get(app.id) == app)
  assert(target == "term" or target == "monitor" or target == "ask")
  local prefs = M.preferences()
  prefs.launchTargets[app.id] = target
  M.savePreferences(prefs)
end
function M.monitors()
  local result = {}
  if peripheral and peripheral.getNames and peripheral.getType and peripheral.wrap then
    for _, name in ipairs(peripheral.getNames()) do
      if peripheral.getType(name) == "monitor" then
        local monitor = peripheral.wrap(name)
        if monitor and monitor.getSize then
          result[#result + 1] = { name = name, screen = monitor }
        end
      end
    end
  end
  table.sort(result, function(a, b)
    return a.name < b.name
  end)
  return result
end
function M.disks(app)
  local result = { { name = "Computer", root = app.root, mount = "/" } }
  if peripheral and peripheral.getNames and peripheral.getType and peripheral.call then
    for _, name in ipairs(peripheral.getNames()) do
      if peripheral.getType(name) == "drive" then
        local ok, mount = pcall(peripheral.call, name, "getMountPath")
        if ok and type(mount) == "string" and mount ~= "" then
          local path = "/" .. mount:gsub("^/", "")
          if fs.exists(path) and (not fs.isReadOnly or not fs.isReadOnly(path)) then
            result[#result + 1] = {
              name = path,
              mount = path,
              root = path .. "/" .. (app.category == "Games" and "games" or "apps") .. "/" .. app.id,
            }
          end
        end
      end
    end
  end
  return result
end
function M.validateRoot(app, root)
  root = root or M.installRoot(app)
  for _, disk in ipairs(M.disks(app)) do
    if disk.root == root then
      return root
    end
  end
  error("Installation destination is unavailable or read-only: " .. tostring(root), 0)
end
function M.syncOpus()
  local ok, opus = pcall(function()
    if type(require) == "function" then
      return require("apps.fpbstore.opus")
    end
    return dofile("/apps/fpbstore/opus.lua")
  end)
  if ok and opus and opus.sync then
    return pcall(opus.sync, M.catalog.apps, M.installed, M.preferences())
  end
  return false
end
local latest = {}
local checked = false
local latestStore = nil
local latestCommit = nil
local snapshots = {}

local function markerPath(app)
  return "/apps/fpbstore/installed/" .. app.id .. ".dat"
end

local function markerFor(app)
  local h = fs.open(markerPath(app), "r")
  if not h then
    return nil
  end
  local ok, data = pcall(textutils.unserialize, h.readAll())
  h.close()
  return ok and type(data) == "table" and data or nil
end

local function readVersion(app)
  local marker = markerFor(app)
  if marker and type(marker.version) == "string" then
    return marker.version
  end
  local h = fs.open(M.installRoot(app) .. app.entry:sub(#app.root + 1), "r")
  if h then
    local header = (h.read and h.read(400) or h.readAll()) or ""
    h.close()
    return header:match("[Vv](%d+%.%d+%.%d+)") or header:match("[Vv](%d+%.%d+)")
  end
  return nil
end

local function validateBranch(value)
  assert(
    type(value) == "string"
      and #value > 0
      and #value <= 200
      and value:match("^[%w%._/-]+$")
      and value:sub(1, 1) ~= "/"
      and value:sub(-1) ~= "/"
      and not value:find("..", 1, true)
      and not value:find("//", 1, true),
    "Invalid branch name"
  )
  return value
end

-- PR numbers and URLs are accepted alongside ordinary branch names.
function M.parseSource(input, mode)
  assert(type(input) == "string", "Enter a PR number or branch name")
  local value = input:match("^%s*(.-)%s*$")
  local prUrl = value:match("^https://github%.com/fpbcraft/cc%-scripts/pull/(%d+)/?$")
  local branchUrl = value:match("^https://github%.com/fpbcraft/cc%-scripts/tree/(.+)$")
  if value:find("://", 1, true) and not (prUrl or branchUrl) then
    error("Use a PR or branch URL from fpbcraft/cc-scripts", 0)
  end
  if prUrl then
    value = prUrl
    mode = "pr"
  elseif branchUrl then
    value = branchUrl
    mode = "branch"
  end
  if not mode or mode == "auto" then
    if value:match("^#?%d+$") or value:match("^pr/?%d+$") or value:match("^pull/%d+$") then
      mode = "pr"
    else
      mode = "branch"
    end
  end
  if mode == "main" or (value == "main" and mode == "branch") then
    return { kind = "main", value = "main", label = "main" }
  end
  if mode == "pr" then
    local number = value:match("^#?(%d+)$") or value:match("^pr/?(%d+)$") or value:match("^pull/(%d+)$")
    assert(number and tonumber(number) and tonumber(number) > 0, "Enter a valid PR number (e.g. 52)")
    number = tostring(tonumber(number))
    return { kind = "pr", value = number, label = "PR #" .. number }
  end
  assert(mode == "branch", "Unknown build source")
  return { kind = "branch", value = validateBranch(value), label = value }
end

local function sourceKey(source)
  return source.kind .. ":" .. source.value
end

function M.installedSource(app)
  local marker = markerFor(app)
  if marker then
    if marker.kind == "pr" or marker.kind == "branch" or marker.kind == "main" then
      local ok, source = pcall(M.parseSource, marker.source or marker.ref or "main", marker.kind)
      if ok then
        return source
      end
    elseif type(marker.ref) == "string" then
      local ok, source = pcall(M.parseSource, marker.ref)
      if ok then
        return source
      end
    end
  end
  return M.parseSource("main")
end

local function api(path)
  assert(http and http.get and textutils and textutils.unserializeJSON, "GitHub API is unavailable")
  local separator = path:find("?", 1, true) and "&" or "?"
  local nonce = os.epoch and os.epoch("utc") or math.floor(os.clock() * 1000)
  local url = "https://api.github.com/repos/fpbcraft/cc-scripts/" .. path .. separator .. "fpbstore_cb=" .. nonce
  local h, err =
    http.get(url, { ["Accept"] = "application/vnd.github+json", ["User-Agent"] = "FPBStore-CraftOS" }, true)
  assert(h, "GitHub API request failed: " .. tostring(err))
  local status = h.getResponseCode and h.getResponseCode() or 200
  local body = h.readAll()
  h.close()
  assert(status == 200, "GitHub API returned HTTP " .. tostring(status) .. " for " .. path)
  local decoded = textutils.unserializeJSON(body)
  assert(type(decoded) == "table", "Invalid GitHub API response")
  return decoded
end

local function shaIsValid(sha)
  return type(sha) == "string" and #sha == 40 and sha:match("^[a-fA-F0-9]+$") ~= nil
end

local function resolveSha(source)
  local response
  if source.kind == "pr" then
    response = api("pulls/" .. source.value)
    assert(response.head and shaIsValid(response.head.sha), "PR has no downloadable head commit")
    assert(
      response.head.repo and response.head.repo.full_name == "fpbcraft/cc-scripts",
      "Only PRs from fpbcraft/cc-scripts branches are currently supported"
    )
    return response.head.sha
  end
  -- Slash-containing branch names work with the commits endpoint.
  response = api("commits/" .. source.value:gsub("/", "%%2F"))
  assert(shaIsValid(response.sha), "Branch does not resolve to a commit")
  return response.sha
end

local function decodeCatalog(body)
  local fn, err = load(body, "@remote-catalog.lua", "t", { ipairs = ipairs })
  assert(fn, err)
  local remote = fn()
  assert(type(remote) == "table" and type(remote.apps) == "table", "Invalid remote catalog")
  return remote
end

local function versionsOf(remote)
  local result = {}
  for _, app in ipairs(remote.apps) do
    if type(app.id) == "string" and type(app.version) == "string" then
      result[app.id] = app.version
    end
  end
  return result
end

-- Compare only a package's own program files and bundled runtime libraries.
-- Repository-wide commits (including Store-only updates) are irrelevant.
local function fingerprint(remote, tree, id)
  local spec = remote.packages and remote.packages[id]
  if not spec or not tree or type(spec.source) ~= "string" then
    return nil
  end
  local paths = {}
  for _, name in ipairs(spec.files or {}) do
    paths[#paths + 1] = spec.source .. "/" .. name
  end
  for _, name in ipairs(spec.libraries or {}) do
    paths[#paths + 1] = "lib/fpb/" .. name .. ".lua"
  end
  table.sort(paths)
  local entries = {}
  for _, path in ipairs(paths) do
    if not tree[path] then
      return nil
    end
    entries[#entries + 1] = path .. ":" .. tree[path]
  end
  return table.concat(entries, "|")
end

local function loadSnapshot(source)
  local key = sourceKey(source)
  if snapshots[key] then
    return snapshots[key]
  end
  local sha = resolveSha(source)
  local remote = decodeCatalog(fetch(M.BASE .. sha .. "/lib/fpb/packages.lua"))
  local treeResponse = api("git/trees/" .. sha .. "?recursive=1")
  local tree = {}
  if treeResponse.truncated ~= true and type(treeResponse.tree) == "table" then
    for _, item in ipairs(treeResponse.tree) do
      if item.type == "blob" then
        tree[item.path] = item.sha
      end
    end
  end
  local snapshot = { sha = sha, remote = remote, versions = versionsOf(remote), fingerprints = {} }
  for id in pairs(remote.packages or {}) do
    snapshot.fingerprints[id] = fingerprint(remote, tree, id)
  end
  snapshots[key] = snapshot
  return snapshot
end

local function fallbackMain()
  local remote = decodeCatalog(fetch(M.BASE .. "main/lib/fpb/packages.lua"))
  return { sha = nil, remote = remote, versions = versionsOf(remote), fingerprints = {} }
end

function M.remoteRevision()
  return latestCommit
end

function M.refreshVersions()
  snapshots = {} -- An explicit refresh must recheck branch and PR heads.
  latestCommit = nil
  local ok, main = pcall(loadSnapshot, M.parseSource("main"))
  if not ok then
    local fallbackOk, fallback = pcall(fallbackMain)
    if not fallbackOk then
      checked = true
      return false, tostring(fallback)
    end
    main = fallback
  end
  snapshots["main:main"] = main
  latestCommit = main.sha
  latest = main.versions
  latestStore = main.remote.storeVersion
  checked = true
  -- Keep non-main installations on their own source. A failed check does not
  -- prevent launching offline or make them look outdated against main.
  for _, app in ipairs(C.apps) do
    if M.installed(app) then
      local source = M.installedSource(app)
      if source.kind ~= "main" then
        pcall(loadSnapshot, source)
      end
    end
  end
  return true
end

local function resolveRef(ref)
  if ref ~= "main" then
    return ref
  end
  if latestCommit then
    return latestCommit
  end
  local ok, sha = pcall(resolveSha, M.parseSource("main"))
  if ok then
    latestCommit = sha
    return sha
  end
  return ref
end
local function parts(version)
  local a, b, c = tostring(version or ""):match("^(%d+)%.(%d+)%.?(%d*)$")
  if not a then
    return nil
  end
  return { tonumber(a), tonumber(b), tonumber(c) or 0 }
end
local function newer(a, b)
  local x, y = parts(a), parts(b)
  if not x or not y then
    return false
  end
  for i = 1, 3 do
    if x[i] ~= y[i] then
      return x[i] > y[i]
    end
  end
  return false
end
function M.storeStatus()
  local installed = C.storeVersion
  local available = latestStore or installed
  return {
    installedVersion = installed,
    latestVersion = available,
    updateAvailable = latestStore ~= nil and newer(available, installed),
    checked = checked,
  }
end

function M.installedRevision(app)
  local marker = markerFor(app)
  return marker and type(marker.commit) == "string" and marker.commit or nil
end

function M.status(app)
  local marker = markerFor(app)
  local installed = M.installed(app)
  local source = M.installedSource(app)
  local snapshot = snapshots[sourceKey(source)]
  local current = installed and readVersion(app) or nil
  local available = snapshot and snapshot.versions[app.id]
    or (source.kind == "main" and latest[app.id])
    or current
    or app.version
  local remoteFingerprint = snapshot and snapshot.fingerprints[app.id]
  local updateAvailable = false
  if installed then
    if remoteFingerprint and marker and marker.fingerprint then
      updateAvailable = remoteFingerprint ~= marker.fingerprint
    elseif source.kind == "main" and current and available then
      -- Older Store installations have no file fingerprint yet.
      updateAvailable = newer(available, current)
    end
  end
  return {
    installed = installed,
    managed = fs.exists(markerPath(app)),
    installedVersion = current,
    latestVersion = available,
    updateAvailable = updateAvailable,
    versionUnknown = installed and current == nil,
    source = source,
    commit = marker and marker.commit,
    checked = checked,
    root = M.installRoot(app),
    launchTarget = M.preferences().launchTargets[app.id] or "ask",
  }
end

function M.install(app, ref, root)
  assert(app and M.get(app.id) == app, "Unrecognized app")
  local source
  if ref == nil then
    source = M.installedSource(app)
  elseif type(ref) == "table" then
    source = M.parseSource(ref.value, ref.kind)
  else
    source = M.parseSource(ref)
  end
  local snapshot = snapshots[sourceKey(source)]
  if not snapshot then
    local ok, result = pcall(loadSnapshot, source)
    if ok then
      snapshot = result
    elseif source.kind ~= "main" then
      error("Cannot resolve " .. source.label .. ": " .. tostring(result), 0)
    end
  end
  root = M.validateRoot(app, root)
  local pinned = snapshot and snapshot.sha or resolveRef("main")
  local code = fetch(M.BASE .. pinned .. "/" .. app.installer)
  local chunk, err = load(code, "@" .. app.installer, "t", _ENV)
  assert(chunk, "Invalid installer: " .. tostring(err))
  local ok, result = xpcall(function()
    return chunk(pinned, "--no-startup", "--root=" .. root)
  end, function(e)
    return tostring(e) .. (debug and debug.traceback and ("\n" .. debug.traceback()) or "")
  end)
  assert(ok, "Installation of " .. app.name .. " failed:\n" .. tostring(result))
  assert(
    fs.exists(root .. app.entry:sub(#app.root + 1)),
    "Installer returned without installing " .. app.name .. " at " .. root
  )
  ensure("/apps/fpbstore/installed")
  write(
    markerPath(app),
    textutils.serialize({
      kind = source.kind,
      source = source.value,
      ref = source.kind == "pr" and ("pr/" .. source.value) or source.value,
      commit = shaIsValid(pinned) and pinned or nil,
      fingerprint = snapshot and snapshot.fingerprints[app.id] or nil,
      version = snapshot and snapshot.versions[app.id] or (source.kind == "main" and latest[app.id]) or app.version,
      installedAt = os.epoch and os.epoch("utc") or 0,
      root = root,
    })
  )
  M.syncOpus()
  return true
end

function M.launch(app)
  assert(app and M.get(app.id) == app and M.installed(app), "App not installed")
  local root = M.installRoot(app)
  local file, err = loadfile(root .. "/_lib/fpb/loader.lua")
  assert(file, "Missing app loader; reinstall " .. app.name .. ": " .. tostring(err))
  local loader = file()
  assert(type(loader) == "table" and type(loader.run) == "function", "Invalid app loader")
  local entry = app.entry:sub(#app.root + 2)
  if app.id == "civcraft" then
    return loader.run(root, entry, _ENV, "local")
  end
  return loader.run(root, entry, _ENV)
end
function M.remove(app, deleteSaves)
  assert(app and M.get(app.id) == app, "Unrecognized app")
  local count = 0
  local root = M.installRoot(app)
  -- Never delete the game root: unrecognized files may contain user work.
  for _, relative in ipairs(app.managedFiles) do
    assert(
      relative:match("^[%w%._/-]+$") and not relative:find("..", 1, true) and relative:sub(1, 1) ~= "/",
      "Unsafe managed file path"
    )
    local path = fs.combine(root, relative)
    if fs.exists(path) and not fs.isDir(path) then
      fs.delete(path)
      count = count + 1
    end
  end
  -- The default is preserve: opting in is explicit and UI-confirmed.
  if deleteSaves then
    for _, save in ipairs(app.saves) do
      assert(save:sub(1, #app.root + 1) == app.root .. "/", "Unsafe save path")
      local actual = root .. save:sub(#app.root + 1)
      if fs.exists(actual) then
        fs.delete(actual)
      end
    end
  end
  local marker = "/apps/fpbstore/installed/" .. app.id .. ".dat"
  if fs.exists(marker) then
    fs.delete(marker)
  end
  M.syncOpus()
  return count
end
function M.updateStore(ref)
  ref = ref or M.REF
  assert(ref:match("^[%w%._/-]+$") and not ref:find("..", 1, true), "Invalid ref")
  local pinned = resolveRef(ref)
  local source = fetch(M.BASE .. pinned .. "/installers/fpbstore.lua")
  local fn, err = load(source, "@installers/fpbstore.lua", "t", _ENV)
  assert(fn, err)
  -- A downloaded installer is already a Lua chunk. Execute it directly:
  -- CraftOS-PC/iOS can run store scripts without a shell instance.
  local ok, result = xpcall(function()
    return fn(pinned)
  end, function(e)
    return tostring(e) .. (debug and debug.traceback and "\\n" .. debug.traceback() or "")
  end)
  assert(ok, "Store update failed: " .. tostring(result))
  return true
end
return M
