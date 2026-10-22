local function runInstall(noStartup)
  local contents={
    ['/startup.lua']="print('original startup')\n",
    ['/.airship_avionics_route']='route-v1',
    ['/fpb-airship/autopilot.lua']='old script',
    ['/fpb-airship/.airship_avionics_presets']='saved presets',
  }
  local dirs={['/fpb-airship']=true,['/']=true}
  fs={}
  function fs.exists(path)return contents[path]~=nil or dirs[path]~=nil end
  function fs.isDir(path)return dirs[path]==true end
  function fs.makeDir(path)dirs[path]=true end
  function fs.combine(a,b)
    if a=='/' then return '/'..b end
    return a..'/'..b
  end
  function fs.delete(path)
    contents[path]=nil;dirs[path]=nil
    for key in pairs(contents) do if key:sub(1,#path+1)==path..'/' then contents[key]=nil end end
  end
  function fs.copy(src,dst)
    assert(contents[src],'missing file for copy: '..src)
    contents[dst]=contents[src]
  end
  function fs.move(src,dst)
    if dirs[src] then
      dirs[dst]=true
      dirs[src]=nil
      local updates={}
      for path,body in pairs(contents) do
        if path:sub(1,#src+1)==src..'/' then
          updates[#updates+1]={from=path,to=dst..path:sub(#src+1),body=body}
        end
      end
      for _,u in ipairs(updates) do contents[u.to]=u.body; contents[u.from]=nil end
    else
      contents[dst]=assert(contents[src],'missing move file '..src)
      contents[src]=nil
    end
  end
  function fs.open(path,mode)
    if mode=='r' then
      if not contents[path] then return nil end
      return {readAll=function()return contents[path] end,close=function()end}
    elseif mode=='w' then
      contents[path]=''
      return {write=function(txt)contents[path]=contents[path]..txt end,close=function()end}
    end
  end
  local repo={
    ['autopilot.lua']='-- airship '..string.rep('A',100),
    ['ui.lua']='-- basename '..string.rep('B',100),
  }
  http={get=function(url)
    local name=url:match('/([^/]+)$')
    assert(repo[name],url)
    return {getResponseCode=function()return 200 end,readAll=function()return repo[name]end,close=function()end}
  end}
  shell={run=function(command,mode,url,arg1,dst)
    assert(command=='wget' and mode=='run' and arg1=='minified')
    contents[dst]='-- basalt '..string.rep('x',100)
    return true
  end}
  settings={get=function()return true end}
  function printError(...)error(table.concat({...},' '))end
  local chunk=assert(loadfile('install-airship.lua'))
  if noStartup then chunk('main','--no-startup') else chunk('main') end
  assert(contents['/fpb-airship/autopilot.lua']==repo['autopilot.lua'])
  assert(contents['/fpb-airship/ui.lua']==repo['ui.lua'])
  assert(contents['/fpb-airship/basalt.lua'])
  assert(contents['/fpb-airship/.airship_avionics_route']=='route-v1')
  assert(contents['/fpb-airship/.airship_avionics_presets']=='saved presets')
  assert(contents['/fpb-airship.backup/autopilot.lua']=='old script')
  if noStartup then assert(contents['/startup.lua']=="print('original startup')\n")
  else
    assert(contents['/startup.lua']=="shell.run('/fpb-airship/autopilot.lua')\n")
    assert(contents['/startup.fpb-airship-backup.lua.old']=="print('original startup')\n")
  end
end
runInstall(false)
runInstall(true)
print('Airship installer test: PASS (swap, data, backup, optional startup)')
