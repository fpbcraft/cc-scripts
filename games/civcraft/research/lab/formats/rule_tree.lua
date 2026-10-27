-- Generated offline policy format; observer-safe vector only.
local M = {["format"]="rule_tree",["schema_version"]="observer-strategic-v1",["features"]={"round_fraction","age_fraction","cities","population","industry","science","gold","treasury_net","technologies","buildings","unit_count","combat_power","idle_cities","research_progress","legal_action_count"},["actions"]={"research:agriculture","research:mining","research:sailing","research:writing","production:settler","production:warrior","production:library","production:mine","production:station","production:bank"},["tree"]={["feature"]=8,["threshold"]=0.0,["left"]={["leaf"]="research:sailing"},["right"]={["feature"]=7,["threshold"]=0.8,["left"]={["leaf"]="research:agriculture"},["right"]={["leaf"]="production:station"}}},["default"]="production:bank"}
local function legal(action, actions)
  for _, candidate in ipairs(actions or {}) do if candidate == action then return action, false end end
  local first = nil
  for _, candidate in ipairs(actions or {}) do if first == nil or candidate < first then first = candidate end end
  return first or "noop", true
end
function M.predict(f, actions)
  local scores = {}
  if M.format == "weights" then
    for i, row in ipairs(M.weights) do local s=M.bias[i] or 0; for j,v in ipairs(row) do s=s+v*(f[j] or 0) end; scores[i]=s end
  elseif M.format == "tiny_quantized_mlp" then
    local h={}; for i,row in ipairs(M.hidden) do local s=0; for j,q in ipairs(row) do s=s+q*(f[j] or 0) end; h[i]=math.max(0,s/(M.hidden_scale or 1)) end
    for i,row in ipairs(M.output) do local s=M.bias[i] or 0; for j,q in ipairs(row) do s=s+q*h[j]/(M.output_scale or 1) end; scores[i]=s end
  else
    local node=M.tree; while node.leaf == nil do node=(f[node.feature+1] or 0) <= node.threshold and node.left or node.right end; return legal(node.leaf,actions)
  end
  local best,bestScore=1,scores[1] or -math.huge; for i=2,#scores do if scores[i] > bestScore then best,bestScore=i,scores[i] end end
  return legal(M.actions[best], actions)
end
return M
