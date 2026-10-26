-- Literal authored boards. Stock, goals and bonus limits are independent of
-- solution witnesses; loading the campaign never transforms a seed puzzle.
local campaign = {}
for district = 1, 8 do
  for _, stage in ipairs(require("games.cogworks.campaign.district_" .. district)) do
    campaign[#campaign + 1] = stage
  end
end
return campaign
