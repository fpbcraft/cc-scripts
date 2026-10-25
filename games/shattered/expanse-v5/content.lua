-- SHATTERED v5: content is data, never coupled to display or peripherals.
local C = {}
C.factions = {
  { name = "IMPERIUM", trait = "RESOLUTE", desc = "Fleets cost one less Alloy. Warships get +1 strength.", color = 14 },
  { name = "CONCORD", trait = "IDEALIST", desc = "Diplomatic offers are more likely to succeed.", color = 9 },
  { name = "ASCENDANCY", trait = "CURIOUS", desc = "Earn +2 Knowledge when a scout discovers a system.", color = 13 },
  { name = "FREE SYSTEMS", trait = "PRAGMATIC", desc = "Earn +2 Credits from Commerce colonies.", color = 17 },
}
C.systemTypes = {
  { id = "GARDEN", kind = "commerce", desc = "Fertile and hospitable." },
  { id = "FORGE", kind = "industry", desc = "Rich in workable mineral deposits." },
  { id = "RELIC", kind = "science", desc = "Ruins of the shattered civilization." },
  { id = "SANCTUARY", kind = "commerce", desc = "Home to peaceful enclaves." },
  { id = "RIFT", kind = "science", desc = "Dangerous space with strange signals." },
  { id = "BASTION", kind = "industry", desc = "A defensible strategic junction." },
  { id = "FRONTIER", kind = "industry", desc = "Sparse but ripe for development." },
}
C.names = {
  "ASTRA",
  "MERIDIAN",
  "HELIOS",
  "TALOS",
  "VESPER",
  "VULCAN",
  "LYRA",
  "CIRRUS",
  "NEXUS",
  "ORION",
  "ATLAS",
  "AEGIS",
  "TERRA",
  "MIRA",
  "CYGNUS",
  "ARCADIA",
  "SIRIUS",
  "EDEN",
  "EMBER",
  "ZENITH",
  "TITAN",
  "SOLACE",
  "IRIS",
  "OMEGA",
  "KHEPRI",
  "VEGA",
  "KEPLER",
  "DENEB",
  "HELIX",
  "DRACO",
}
C.focus = {
  industry = {
    name = "INDUSTRY",
    icon = "forge",
    description = "Produce 4 extra Alloy yearly. Forge worlds produce 2 more.",
    cost = { credits = 7 },
  },
  science = {
    name = "SCIENCE",
    icon = "lab",
    description = "Produce 4 extra Knowledge yearly. Relic worlds produce 2 more.",
    cost = { credits = 7 },
  },
  commerce = {
    name = "COMMERCE",
    icon = "trade",
    description = "Produce 4 extra Credits yearly. Garden worlds produce 2 more.",
    cost = { credits = 7 },
  },
}
C.ships = {
  scout = {
    name = "SCOUT",
    icon = "scan",
    description = "Explore connected systems and reveal ancient discoveries.",
    cost = { alloy = 7, credits = 3 },
    moves = 2,
    power = 0,
  },
  ark = {
    name = "COLONY ARK",
    icon = "colony",
    description = "Found a colony on a discovered, unclaimed system adjacent to your borders.",
    cost = { alloy = 12, credits = 5 },
    moves = 2,
    power = 0,
  },
  fleet = {
    name = "FLEET",
    icon = "ship",
    description = "Protect borders and capture systems belonging to empires at war.",
    cost = { alloy = 10, credits = 5 },
    moves = 2,
    power = 5,
  },
}
C.tech = {
  exploration = {
    { name = "DEEP SCANNERS", cost = 12, description = "Scouts reveal connected systems when they arrive." },
    { name = "XENOARCHAEOLOGY", cost = 20, description = "Exploring a Relic grants 6 extra Knowledge." },
    { name = "STAR CHARTS", cost = 30, description = "Complete this path to unlock the Discovery project." },
  },
  prosperity = {
    { name = "TRADE NETWORKS", cost = 12, description = "Commerce colonies produce 2 extra Credits yearly." },
    { name = "DIPLOMATIC CORPS", cost = 20, description = "Diplomatic offers receive a relationship bonus." },
    { name = "PROSPERITY CHARTER", cost = 30, description = "Your colonies produce 1 extra of their specialized resource." },
  },
  warfare = {
    { name = "FLEET DOCTRINE", cost = 12, description = "Fleets gain +2 strength in battle." },
    { name = "HEAVY ARMAMENTS", cost = 20, description = "Fleets gain another +2 strength in battle." },
    { name = "FRONTIER FORTRESS", cost = 30, description = "Defending owned systems gain +3 strength." },
  },
}
C.pacts = {
  trade = { name = "TRADE", desc = "Both empires receive +2 Credits each galactic year." },
  nonaggression = { name = "NON-AGGRESSION", desc = "Promise not to attack one another; declaring war breaks trust." },
  alliance = { name = "ALLIANCE", desc = "An enduring partnership. Two alliances can qualify for Unity victory." },
}
C.win = {
  discovery = "Complete Exploration research and the two-year Ancient Archive project.",
  unity = "Maintain two alliances and complete the two-year Galactic Accord project.",
  dominion = "Control at least 15 of the 30 star systems.",
}
return C
