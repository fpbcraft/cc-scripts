-- THE SHATTERED EXPANSE: data definitions. All costs in Credits / Materials / Aether.
local C={}
C.archetypes={
 {id="imperium",name="IMPERIUM",description="Disciplined fleets and hardened borders.",bonus="MILITARY",home="BASTION",trait="RESOLUTE",colour=14},
 {id="concord",name="CONCORD",description="Open diplomacy and scientific exploration.",bonus="DIPLOMACY",home="SANCTUARY",trait="IDEALIST",colour=9},
 {id="ascendancy",name="ASCENDANCY",description="Relic seekers willing to take great risks.",bonus="DISCOVERY",home="RELIC",trait="CURIOUS",colour=13},
 {id="free",name="FREE SYSTEMS",description="Prosperous traders and independent pioneers.",bonus="TRADE",home="FREEPORT",trait="PRAGMATIC",colour=17},
}
C.systemTypes={"CORE","FORGE","DEAD","RELIC","RIFT","SANCTUARY","FORTRESS","FREEPORT","GARDEN","MINERAL"}
C.names={"ASTRA","MERIDIAN","HELIOS","TALOS","VESPER","VULCAN","LYRA","CIRRUS","NEXUS","ORION","ATLAS","AEGIS","TERRA","MIRA","CYGNUS","ARCADIA","SIRIUS","EDEN","EMBER","ZENITH","TITAN","SOLACE","IRIS","OMEGA","KHEPRI","VEGA","KEPLER","DENEB","HELIX","KOR","IONA","DRACO","ERIDAN","PHOBOS","RHEA","XENON","THALASSA","PROXIMA","OBERON","ELARA","JANUS","BELLATRIX","PRAXIS","NOCTIS","LUMEN","CAELUM"}
C.buildings={
 mine={name="MINING COMPLEX",cost={credits=7,materials=5},time=1,desc="Produces 3 Materials per round. Forge and Mineral worlds give +1."},
 exchange={name="TRADE EXCHANGE",cost={credits=5,materials=5},time=1,desc="Produces 4 Credits per round; opens stronger economic routes."},
 lab={name="RESEARCH LAB",cost={credits=8,materials=6},time=2,desc="Produces 3 Research per round; Relic worlds give +2."},
 shipyard={name="ORBITAL YARD",cost={credits=10,materials=8},time=2,desc="Construct ships and strengthen nearby fleet resupply."},
 bastion={name="FORTRESS",cost={credits=8,materials=7},time=2,desc="Adds defense to fleets fighting over this system."},
 extractor={name="AETHER EXTRACTOR",cost={credits=12,materials=9,aether=0},time=2,desc="Rift worlds only. Produces 1 rare Aether per round."},
}
C.tech={
 engineering={{name="EFFICIENT FORGES",cost=12,desc="+1 Materials per mining complex."},{name="INDUSTRIAL METHODS",cost=19,desc="-20% material building costs (rounded down)."},{name="MEGA STRUCTURES",cost=27,desc="Advanced projects and +1 colony slot."},{name="AUTONOMOUS FOUNDRIES",cost=35,desc="+1 Materials per colony."}},
 physics={{name="SHIELD ARRAYS",cost=12,desc="+1 fleet strength per warship."},{name="CRUISER HULLS",cost=19,desc="Unlocks powerful cruisers."},{name="AETHER DRIVES",cost=27,desc="Unlocks capital ships and better mobility."},{name="SINGULARITY THEORY",cost=35,desc="Required for the Transcendence project."}},
 society={{name="EMBASSIES",cost=12,desc="+12 approval to diplomatic offers."},{name="CIVIC PLANNING",cost=19,desc="+1 colony district slot."},{name="GALACTIC CHARTER",cost=27,desc="Enables Diplomatic victory project."},{name="SHARED PROSPERITY",cost=35,desc="+2 Credits per colony."}},
 exploration={{name="DEEP SCANNERS",cost=12,desc="Exploration ships get +1 movement each round."},{name="XENO ARCHAEOLOGY",cost=19,desc="+50% relic research and anomalies."},{name="FRONTIER SURVEY",cost=27,desc="Reduce outpost costs; gain a colony slot."},{name="PRECURSOR LORE",cost=35,desc="Required for Transcendence project."}},
}
C.shipClasses={
 scout={name="SCIENCE VESSEL",cost={credits=5,materials=5},ap=2,power=0,desc="Reveals unknown systems and investigates anomalies."},
 builder={name="CONSTRUCTION SHIP",cost={credits=6,materials=6},ap=2,power=0,desc="Establishes outposts and colonies."},
 frigate={name="FRIGATE",cost={credits=5,materials=6},ap=2,power=3,desc="Cheap frontline warship."},
 cruiser={name="CRUISER",cost={credits=12,materials=12},ap=2,power=7,desc="Versatile warship; requires Cruiser Hulls."},
 capital={name="CAPITAL SHIP",cost={credits=22,materials=20,aether=3},ap=1,power=15,desc="Powerful flagship; requires Aether Drives."},
}
C.pacts={
 trade={name="TRADE ACCORD",desc="Both civilizations gain +2 Credits per round."},
 research={name="RESEARCH SHARING",desc="Both civilizations gain +2 Research per round."},
 nonaggression={name="NON-AGGRESSION",desc="Guarantees peace until a civilization breaks the pact."},
 alliance={name="DEFENSIVE ALLIANCE",desc="Improves mutual relations, counts toward diplomatic victory."},
 peace={name="PEACE TREATY",desc="Ends an ongoing war if the other civilization accepts."},
}
C.leaders={"ELARA VOSS","TARIN KESH","MAE SOLARI","IVEN DAX","NALIA KOR","ORIN VALE","SERA QUILL","JUNO ARDEN"}
C.personalities={"IDEALIST","RUTHLESS","CURIOUS","PRAGMATIC","CAUTIOUS","ZEALOUS"}
return C