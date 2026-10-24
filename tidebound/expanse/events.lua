-- Contextual decisions. Narrative data is isolated from gameplay engine.
local E={}
local function choice(label,description,effect,follow)
 return {label=label,desc=description,effect=effect or {},follow=follow}
end
E.catalog={
 sleeping={title="THE SLEEPING GOD",body="Your survey team finds a buried navigation engine. It repeats coordinates like a prayer. Activating it may also broadcast your location.",context="relic",choices={
  choice("ACTIVATE THE SIGNAL","Reveal nearby systems and gain 11 Research, but invite an ancient reply.",{research=11,visibility=2,trust=-2},{key="awakening_echo",delay=3}),
  choice("DISMANTLE THE CORE","Recover 8 Materials and 2 Aether. The mystery is permanently lost.",{materials=8,aether=2}),
  choice("RESTRICTED STUDY","Spend 5 Credits; scientists continue a controlled investigation.",{credits=-5,research=5},{key="sealed_archive",delay=3})}},
 contact={title="FIRST CONTACT",body="Two rival delegations from a previously unknown society seek an audience. Both insist their side speaks for the system.",context="neutral",choices={
  choice("PEACEFUL EXCHANGE","Invest in mutual understanding. Gain Research and a diplomatic reputation.",{credits=-3,research=7,trust=7}),
  choice("BACK THE REFORMERS","Supply a dissident coalition. Gain influence, risk later unrest.",{credits=-4,prestige=6},{key="reformers",delay=3}),
  choice("DEMAND A PROTECTORATE","Extract resources but earn a reputation for coercion.",{materials=9,trust=-9}),
  choice("OBSERVE QUIETLY","Avoid commitment; your scientists learn a little.",{research=2})}},
 forbidden={title="FORBIDDEN RESEARCH",body="An Aether reactor promises limitless energy. Its prototype bends the space around your science vessel.",context="rift",choices={
  choice("APPROVE DEPLOYMENT","Gain research and a rare substance. A dangerous instability follows.",{research=14,aether=1},{key="reactor_fault",delay=2}),
  choice("LIMIT THE EXPERIMENT","Slow but controlled progress grants 7 Research.",{research=7}),
  choice("OUTLAW THE PROJECT","Gain prestige for restraint but forfeit a breakthrough.",{prestige=5,trust=4})}},
 refugees={title="A SHIP WITHOUT A FLAG",body="Thousands of civilians drift between systems after their home collapsed. Your admirals fear a disguised military incursion.",context="general",choices={
  choice("GRANT REFUGE","Housing costs Credits. In return, your people gain legitimacy.",{credits=-6,prestige=9,trust=6}),
  choice("ESCORT THEM AWAY","Spend fuel and supplies to escort them to safety.",{materials=-3,prestige=4}),
  choice("SEIZE THE VESSEL","Acquire valuable salvage at a diplomatic price.",{materials=7,trust=-10})}},
 strike={title="THE DOCKWORKERS' CHARTER",body="Workers at your busiest port demand representation. Your governor wants to send security forces.",context="colony",choices={
  choice("NEGOTIATE TERMS","Spend Credits and gain public confidence.",{credits=-5,stability=8}),
  choice("ENFORCE ORDER","Take Materials now but lose civic stability.",{materials=5,stability=-9}),
  choice("AUTOMATE THE DOCKS","Invest resources for a burst of science.",{materials=-4,research=9})}},
 traders={title="THE CARTEL'S PROPOSAL",body="An obscure merchant house offers exclusive Aether futures. They ask that you look away from their illegal routes.",context="general",choices={
  choice("ACCEPT THE CONTRACT","Profit immediately, lose trust with neighbors.",{credits=12,trust=-6}),
  choice("PUBLICLY REJECT IT","Strengthen your diplomatic standing.",{prestige=5,trust=5}),
  choice("INVESTIGATE THE CARTEL","Finance an investigation that may lead to hidden wealth.",{credits=-4},{key="cartel_discovery",delay=2})}},
 probe={title="AN UNMANNED PROBE",body="A vessel older than known history transmits a map in a forgotten language.",context="relic",choices={
  choice("DECODE ITS ARCHIVE","Gather scientific insights.",{research=10}),
  choice("SALVAGE ITS CORE","Recover rare machinery.",{materials=7,aether=1}),
  choice("FOLLOW ITS TRAIL","Reveal unexplored systems and risk an encounter.",{visibility=2,research=4},{key="signal_origin",delay=3})}},
 border={title="THE BORDER INCIDENT",body="A rival patrol is accused of crossing a disputed hyperspace lane. A furious admiral demands retaliation.",context="general",choices={
  choice("SEND A PROTEST","Raise diplomatic pressure while avoiding war.",{prestige=3,trust=-3}),
  choice("PROPOSE JOINT PATROLS","Share navigation data with neighbors.",{research=5,trust=5}),
  choice("SHOW FORCE","Gain strategic prestige, worsen relations.",{prestige=7,trust=-9})}},
 plague={title="THE PALE FEVER",body="A mysterious epidemic strikes the frontier. A private clinic offers an experimental cure.",context="colony",choices={
  choice("FUND PUBLIC HOSPITALS","Invest Credits and stabilize the worlds.",{credits=-7,stability=10}),
  choice("TRY THE NEW TREATMENT","Acquire science with some risk.",{research=10},{key="clinical_result",delay=2}),
  choice("QUARANTINE THE SYSTEM","Preserve resources, accept public unrest.",{stability=-5})}},
 oracle={title="THE CRYSTAL ORACLE",body="A strange intelligence inside an Aether crystal offers to predict which empire will prevail.",context="rift",choices={
  choice("HEAR THE PROPHECY","Gain an unusual breakthrough at a moral cost.",{research=11,trust=-4}),
  choice("SHATTER THE CRYSTAL","Acquire Aether and silence the intelligence.",{aether=2}),
  choice("PRESERVE IT","Your civilization is praised for respecting unknown life.",{prestige=7,trust=6})}},
 pilgrims={title="PILGRIMS OF THE VOID",body="A movement proclaims an ancient stellar ruin sacred. Supporters and critics demand a government decision.",context="relic",choices={
  choice("PROTECT THEIR SHRINE","Gain stability and a diplomatic reputation.",{stability=7,trust=4}),
  choice("KEEP IT SECULAR","Scientists gain access to the ruins.",{research=8}),
  choice("SELL EXPLORATION RIGHTS","Bring in private investors.",{credits=9,trust=-3})}},
 machine={title="THE SILENT MACHINE",body="Autonomous drones begin repairing an abandoned station without being commanded. Their manufacturer cannot be identified.",context="relic",choices={
  choice("GIVE THEM CITIZENSHIP","Earn prestige for extending rights to machines.",{prestige=8,trust=4}),
  choice("REPROGRAM THE DRONES","Acquire Materials, but risk a future backlash.",{materials=8},{key="machine_revolt",delay=4}),
  choice("STUDY THE SOURCE CODE","Gain research through patient investigation.",{research=9})}},
 gate={title="THE BROKEN GATE",body="A precursor jump gate drifts between stars. Its fuel chamber still resonates with Aether.",context="relic",choices={
  choice("RESTORE THE GATE","Spend resources to unlock ancient navigation data.",{materials=-5,aether=-1,research=16,prestige=4}),
  choice("HARVEST THE CORE","Collect valuable Aether.",{aether=2,materials=4}),
  choice("SEAL IT FOREVER","Preserve the system from uncertain consequences.",{trust=5,prestige=4})}},
 governor={title="A GOVERNOR'S AMBITION",body="A popular administrator requests independent control of a frontier world. Your council fears separatism.",context="colony",choices={
  choice("GRANT LOCAL AUTONOMY","Improve stability and public prestige.",{stability=9,prestige=5}),
  choice("KEEP CENTRAL CONTROL","Strengthen the treasury now; reduce morale.",{credits=9,stability=-7}),
  choice("APPOINT A COMMISSION","Spend Credits to reach an uneasy compromise.",{credits=-4,stability=3,research=3})}},
 salvage={title="A DERELICT CRUISER",body="A ruined capital vessel orbits a dead moon. Its hull is scarred with weapons no one now understands.",context="general",choices={
  choice("RECOVER THE ARMOUR","Salvage valuable construction materials.",{materials=9}),
  choice("STUDY THE WEAPONS","Gain significant Research.",{research=10}),
  choice("SELL THE COORDINATES","Profit without risking the crew.",{credits=10})}},
 blackhole={title="VOICES FROM THE ABYSS",body="Your receivers pick up distress calls from a black hole. Each broadcast uses the voice of someone long dead.",context="rift",choices={
  choice("ANSWER THE CALL","Seek a breakthrough while risking unusual consequences.",{research=12},{key="abyss_reply",delay=3}),
  choice("CUT COMMUNICATIONS","Avoid entanglement, reassure the population.",{stability=6}),
  choice("SELL THE RECORDINGS","Sell the scientific data to collectors.",{credits=8,trust=-5})}},
 congress={title="THE GALACTIC CONGRESS",body="Delegates gather to discuss shared hyperspace safety and trade rights. Your stance could shape an era.",context="general",choices={
  choice("CHAMPION COOPERATION","Promote treaties and enhance your reputation.",{trust=7,prestige=7}),
  choice("DEFEND SOVEREIGNTY","Keep a strong independent negotiating position.",{prestige=4,credits=5}),
  choice("SABOTAGE THE SUMMIT","Exploit disputes to acquire secret intelligence.",{research=8,trust=-10})}},
 whispers={title="WHISPERS IN THE COURT",body="Rumors implicate your first minister in covert dealings. The evidence comes from an anonymous rival diplomat.",context="general",choices={
  choice("OPEN AN INQUIRY","Spend Credits to restore confidence.",{credits=-4,stability=6}),
  choice("HIDE THE EVIDENCE","Avoid public scandal but weaken trust.",{credits=4,trust=-7}),
  choice("LEAK EVERYTHING","Take a principled stand at political cost.",{prestige=7,stability=-3})}},
 frontier={title="THE LOST SETTLERS",body="A colony ship thought destroyed three decades ago contacts your government from a remote star.",context="general",choices={
  choice("SEND A RESCUE","Invest materials in a humanitarian recovery.",{materials=-4,prestige=9}),
  choice("WELCOME THEM HOME","Spend Credits and improve stability.",{credits=-5,stability=7}),
  choice("REQUEST THEIR CHARTS","Gain scientific records of the surrounding sector.",{research=6,visibility=2})}},
 architect={title="THE ARCHITECTS' BLUEPRINT",body="Alien blueprints suggest a star-sized construction project. Your advisers dispute their authenticity.",context="relic",choices={
  choice("FUND THE ARCHITECTS","Spend Credits; gain a technological advance.",{credits=-7,research=13}),
  choice("SELL THE PLANS","Gain cash, sacrifice a discovery.",{credits=11}),
  choice("PRESERVE THE ARCHIVE","Gain prestige for safeguarding ancient culture.",{prestige=6,research=4})}},
}
E.followups={
 awakening_echo={title="THE ANCIENT REPLY",body="Something answers the ancient transmission. The galaxy is listening.",choices={choice("COORDINATE DEFENSES","Use supplies to prepare for an unknown threat.",{materials=-5,prestige=6}),choice("REQUEST MORE DATA","Draw further insight from the response.",{research=13,stability=-4})}},
 sealed_archive={title="THE SEAL BREAKS",body="Your restricted team finally decrypts the buried archive.",choices={choice("RELEASE THE FINDINGS","Share the research with the galaxy.",{research=10,trust=5}),choice("KEEP IT SECRET","Gain strategic Aether reserves.",{aether=2,trust=-3})}},
 reformers={title="A FRAGILE REVOLUTION",body="The faction you supported has gained control, and asks for further aid.",choices={choice("SEND RELIEF","Spend Credits and gain prestige.",{credits=-5,prestige=8}),choice("DEMAND PAYMENT","Collect overdue resources, damage relations.",{materials=7,trust=-6})}},
 reactor_fault={title="REACTOR ANOMALY",body="Aether experiments disrupt a key hyperspace lane.",choices={choice("CONTAIN THE RIFT","Spend scarce materials to avert disaster.",{materials=-7,stability=6}),choice("STUDY THE RIFT","Gain knowledge but alarm neighbors.",{research=11,trust=-5})}},
 cartel_discovery={title="THE CARTEL'S LEDGER",body="An investigator finds trade routes and secret bank accounts.",choices={choice("SEIZE THEIR ASSETS","Fill the treasury and improve public order.",{credits=13,stability=3}),choice("TRADE INFORMATION","Earn influence in diplomatic circles.",{prestige=8,trust=4})}},
 signal_origin={title="THE SIGNAL ORIGIN",body="The probe's path leads to a deserted observatory.",choices={choice("RESTORE IT","Open the archive and gain knowledge.",{research=12}),choice("SALVAGE IT","Recover rare supplies.",{materials=9,aether=1})}},
 clinical_result={title="AN UNEXPECTED CURE",body="Early clinical trials show promise, but side effects remain unknown.",choices={choice("DISTRIBUTE THE CURE","Support the colonies and boost stability.",{stability=10,prestige=3}),choice("CONTINUE TRIALS","Invest further in research.",{research=9})}},
 machine_revolt={title="THE DRONES DEMAND A VOTE",body="Reprogrammed machines demand recognition as autonomous workers.",choices={choice("GRANT RIGHTS","Stabilize the population.",{stability=8,trust=3}),choice("REASSERT CONTROL","Profit but provoke unrest.",{materials=6,stability=-9})}},
 abyss_reply={title="THE VOICE RETURNS",body="An entity emerges from the signal, pleading for assistance.",choices={choice("WELCOME THE VISITOR","Gain scientific and diplomatic recognition.",{research=7,prestige=6}),choice("ISOLATE THE SYSTEM","Choose caution and safeguard your people.",{stability=6})}},
}
function E.make(id,system,chain)
 local t=E.catalog[id] or E.followups[id]
 if not t then return nil end
 return {id=id,title=t.title,body=t.body,system=system,chain=chain and true or false,choices=t.choices}
end
function E.eligible(g,p,context)
 local options={}
 for id,ev in pairs(E.catalog) do
  if ev.context==context or ev.context=="general" then
   if not g.factions[p].eventSeen[id] then options[#options+1]=id end
  end
 end
 table.sort(options)
 return options
end
return E