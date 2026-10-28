-- Generated offline policy format; observer-safe vector only.
local M = {["format"]="tiny_quantized_mlp",["schema_version"]="observer-strategic-v1",["features"]={"round_fraction","age_fraction","cities","population","industry","science","gold","treasury_net","technologies","buildings","unit_count","combat_power","idle_cities","research_progress","legal_action_count"},["actions"]={"research:agriculture","research:mining","research:sailing","research:writing","production:settler","production:warrior","production:library","production:mine","production:station","production:bank"},["hidden"]={{-15,-4,7,-13,-2,9,-11,0,11,-9,2,13,-7,4,15},{2,13,-7,4,15,-5,6,-14,-3,8,-12,-1,10,-10,1},{-12,-1,10,-10,1,12,-8,3,14,-6,5,-15,-4,7,-13},{5,-15,-4,7,-13,-2,9,-11,0,11,-9,2,13,-7,4},{-9,2,13,-7,4,15,-5,6,-14,-3,8,-12,-1,10,-10},{8,-12,-1,10,-10,1,12,-8,3,14,-6,5,-15,-4,7},{-6,5,-15,-4,7,-13,-2,9,-11,0,11,-9,2,13,-7},{11,-9,2,13,-7,4,15,-5,6,-14,-3,8,-12,-1,10}},["output"]={{3,6,0,0,4,2,1,11},{3,2,0,0,5,2,0,9},{1,1,0,0,6,0,2,7},{3,1,0,0,3,2,0,11},{5,2,0,0,2,1,1,10},{4,2,1,0,6,2,1,11},{2,4,0,0,2,3,0,12},{2,4,1,0,2,2,1,11},{3,2,1,0,5,2,1,11},{3,1,0,0,5,2,1,10}},["hidden_scale"]=15.0,["output_scale"]=12.0,["bias"]={0,0,0,0,0,0,0,0,0,0}}
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
