-- Generated offline policy format; observer-safe vector and ranked candidates only.
local M = {["format"]="rule_tree",["schema_version"]="observer-strategic-v1",["features"]={"round_fraction","age_fraction","cities","population","industry","science","gold","treasury_net","technologies","buildings","unit_count","combat_power","idle_cities","research_progress","legal_action_count"},["actions"]={"production:academy","production:assembly","production:bank","production:bazaar","production:beltlogistics","production:brassengineer","production:brewery","production:burner","production:councilhall","production:crafter","production:crusher","production:deepmine","production:deployer","production:engineer","production:farm","production:freight","production:furnace","production:library","production:market","production:mine","production:mixer","production:pens","production:portal","production:press","production:railengineer","production:redstoneworkshop","production:scout","production:settler","production:smithy","production:station","production:steamplant","production:university","production:walls","production:warrior","production:waterwheel","production:windmill","production:workshop","research:agriculture","research:archery","research:astronomy","research:belts","research:brassworking","research:brewing","research:bronze","research:commerce","research:crafting","research:crushing","research:currency","research:deepmining","research:deployers","research:diamondworking","research:economics","research:education","research:engineering","research:fortification","research:heatedmixing","research:horseback","research:husbandry","research:logistics","research:masonry","research:mechanicalcrafting","research:metallurgy","research:mining","research:nether","research:netherite","research:philosophy","research:precision","research:pressing","research:railways","research:redstone","research:sailing","research:steampower","research:waterpower","research:windpower","research:writing"},["tree"]={["feature"]=8,["threshold"]=0.16666666666666666,["left"]={["feature"]=14,["threshold"]=0.1875,["left"]={["leaf"]="production:mine"},["right"]={["leaf"]="research:writing"}},["right"]={["feature"]=5,["threshold"]=0.475,["left"]={["leaf"]="production:portal"},["right"]={["leaf"]="production:crafter"}}},["default"]="research:writing"}
local function legal(action, actions, candidates)
  for _, candidate in ipairs(actions or {}) do if candidate == action then return action, false end end
  local selected, best = nil, -math.huge
  for _, candidate in ipairs(candidates or {}) do
    if candidate.label and candidate.score and candidate.score > best then selected, best = candidate.label, candidate.score end
  end
  if selected then return selected, true end
  local first = nil
  for _, candidate in ipairs(actions or {}) do if first == nil or candidate < first then first = candidate end end
  return first or "noop", true
end
local function candidateBonus(label, candidates)
  if not candidates or not M.candidate_weight then return 0 end
  local scale, value = 1, 0
  for _, candidate in ipairs(candidates) do scale=math.max(scale, math.abs(candidate.score or 0)) end
  for _, candidate in ipairs(candidates) do if candidate.label == label then value=(candidate.score or 0)/scale end end
  return value * M.candidate_weight
end
function M.predict(f, actions, candidates)
  local scores = {}
  if M.format == "weights" then
    for i, row in ipairs(M.weights) do local s=(M.bias[i] or 0)+candidateBonus(M.actions[i],candidates); for j,v in ipairs(row) do s=s+v*(f[j] or 0) end; scores[i]=s end
  elseif M.format == "tiny_quantized_mlp" then
    local h={}; for i,row in ipairs(M.hidden) do local s=0; for j,q in ipairs(row) do s=s+q*(f[j] or 0) end; h[i]=math.max(0,s/(M.hidden_scale or 1)) end
    for i,row in ipairs(M.output) do local s=(M.bias[i] or 0)+candidateBonus(M.actions[i],candidates); for j,q in ipairs(row) do s=s+q*h[j]/(M.output_scale or 1) end; scores[i]=s end
  else
    local node=M.tree; while node.leaf == nil do node=(f[node.feature+1] or 0) <= node.threshold and node.left or node.right end; return legal(node.leaf,actions,candidates)
  end
  local best,bestScore=nil,-math.huge; for i,action in ipairs(M.actions) do for _,allowed in ipairs(actions or {}) do if action == allowed and scores[i] > bestScore then best,bestScore=i,scores[i] end end end
  return legal(best and M.actions[best] or "noop", actions, candidates)
end
return M
