-- Narrative scenes: short, contextual, with visible and deferred consequences.
local E = {}
local function opt(title, detail, effect, follow)
	return { title = title, detail = detail, effect = effect or {}, follow = follow }
end
E.catalog = {
	beacon = {
		title = "THE SIGNAL BENEATH",
		context = "relic",
		body = "Beneath a dead moon, an impossible machine broadcasts a warning: DO NOT OPEN THE DOOR. The council is divided.",
		choices = {
			opt(
				"STUDY THE MACHINE",
				"+9 Knowledge. New chapter in two years.",
				{ knowledge = 9, ethic = "curious" },
				{ id = "beacon_reply", delay = 2 }
			),
			opt(
				"SEAL THE RUINS",
				"+5 Credits and improved trust. No future risk.",
				{ credits = 5, trust = 5, ethic = "cautious" }
			),
			opt(
				"ACTIVATE THE BEACON",
				"+13 Knowledge, but anger ancient sentinels.",
				{ knowledge = 13, trust = -5, ethic = "bold" },
				{ id = "sentinels", delay = 2 }
			),
		},
	},
	refugees = {
		title = "THE DRIFTING FLEET",
		context = "general",
		body = "A flotilla of refugees requests entry into your territory. Your governors question whether you can afford to help.",
		choices = {
			opt(
				"OFFER SANCTUARY",
				"-5 Credits; diplomatic trust improves.",
				{ credits = -5, trust = 8, ethic = "compassionate" }
			),
			opt(
				"SALVAGE THEIR TECHNOLOGY",
				"+7 Alloy, but damage your reputation.",
				{ alloy = 7, trust = -8, ethic = "ruthless" }
			),
			opt(
				"ESCORT THEM HOME",
				"+5 Knowledge. A captain promises to return.",
				{ knowledge = 5, ethic = "cautious" },
				{ id = "refugees_return", delay = 3 }
			),
		},
	},
	archive = {
		title = "ANCIENT OBSERVATORY",
		context = "relic",
		body = "A station older than the first empires contains intact records, but its defenses are still active.",
		choices = {
			opt(
				"DECODE THE RECORDS",
				"+12 Knowledge; chance for another revelation.",
				{ knowledge = 12, ethic = "curious" },
				{ id = "beacon_reply", delay = 3 }
			),
			opt(
				"STRIP THE MACHINERY",
				"+9 Alloy, +2 Credits.",
				{ alloy = 9, credits = 2, ethic = "pragmatic" }
			),
			opt(
				"PRESERVE THE SITE",
				"+4 Knowledge and improved trust.",
				{ knowledge = 4, trust = 5, ethic = "compassionate" }
			),
		},
	},
	contact = {
		title = "A QUIET FIRST CONTACT",
		context = "general",
		body = "A minor spacefaring people have contacted your scouts. Rival envoys are already approaching.",
		choices = {
			opt(
				"WELCOME DELEGATES",
				"Spend 3 Credits. Gain trust and Knowledge.",
				{ credits = -3, knowledge = 6, trust = 7, ethic = "compassionate" }
			),
			opt(
				"DEMAND TRIBUTE",
				"Gain 9 Credits; relations deteriorate.",
				{ credits = 9, trust = -7, ethic = "ruthless" }
			),
			opt(
				"REMAIN NEUTRAL",
				"+3 Knowledge, no diplomatic risk.",
				{ knowledge = 3, ethic = "cautious" }
			),
		},
	},
	labour = {
		title = "THE COLONY STRIKE",
		context = "colony",
		body = "Industrial crews request representation on the colony council. The governor requests permission to suppress the protest.",
		choices = {
			opt(
				"NEGOTIATE",
				"Pay 4 Credits, improve trust.",
				{ credits = -4, trust = 8, ethic = "compassionate" }
			),
			opt(
				"ORDER MORE SHIFTS",
				"Gain 8 Alloy at a diplomatic cost.",
				{ alloy = 8, trust = -7, ethic = "ruthless" }
			),
			opt(
				"AUTOMATE THE YARDS",
				"Pay 3 Alloy, gain 7 Knowledge.",
				{ alloy = -3, knowledge = 7, ethic = "curious" }
			),
		},
	},
	spore = {
		title = "THE LIVING NEBULA",
		context = "rift",
		body = "A vast cloud appears to react to music transmitted by a science vessel. Your team believes it could be alive.",
		choices = {
			opt(
				"TRY TO COMMUNICATE",
				"+9 Knowledge and stronger trust.",
				{ knowledge = 9, trust = 4, ethic = "compassionate" }
			),
			opt(
				"COLLECT SAMPLES",
				"+6 Alloy and +5 Knowledge.",
				{ alloy = 6, knowledge = 5, ethic = "curious" }
			),
			opt(
				"WITHDRAW",
				"Recover 6 Credits from unused fuel.",
				{ credits = 6, ethic = "cautious" }
			),
		},
	},
	monopoly = {
		title = "THE MERCHANT PRINCES",
		context = "colony",
		body = "A cartel offers to supply essential equipment in exchange for preferential access to your borders.",
		choices = {
			opt(
				"ACCEPT THE CONTRACT",
				"+12 Credits, weaker public trust.",
				{ credits = 12, trust = -6, ethic = "pragmatic" }
			),
			opt(
				"BREAK THE CARTEL",
				"+5 Alloy. Local merchants support you.",
				{ alloy = 5, trust = 3, ethic = "bold" }
			),
			opt(
				"REGULATE THEIR TRADE",
				"+5 Credits, +3 Knowledge.",
				{ credits = 5, knowledge = 3, ethic = "cautious" }
			),
		},
	},
	omen = {
		title = "OMENS IN THE STATIC",
		context = "general",
		body = "A strange transmission reaches every inhabited system. Its mathematical message predicts a war that has not begun.",
		choices = {
			opt(
				"BROADCAST THE WARNING",
				"Diplomatic trust increases.",
				{ trust = 7, ethic = "compassionate" }
			),
			opt(
				"KEEP IT SECRET",
				"+7 Knowledge. The public remains unaware.",
				{ knowledge = 7, ethic = "pragmatic" }
			),
			opt(
				"PREPARE THE FLEET",
				"+7 Alloy and increased suspicion.",
				{ alloy = 7, trust = -4, ethic = "bold" }
			),
		},
	},
	beacon_reply = {
		title = "THE SECOND TRANSMISSION",
		context = "chain",
		body = "The device sends new coordinates. A distant council asks whether the truth is worth awakening more machines.",
		choices = {
			opt(
				"FOLLOW THE COORDINATES",
				"+14 Knowledge. Memories of a lost civilization are revealed.",
				{ knowledge = 14, ethic = "curious" }
			),
			opt(
				"DESTROY THE COORDINATES",
				"+7 Alloy and restored diplomatic trust.",
				{ alloy = 7, trust = 5, ethic = "cautious" }
			),
		},
	},
	sentinels = {
		title = "THE SENTINEL AWAKENS",
		context = "chain",
		body = "An ancient guardian has intercepted your broadcast. It offers an ultimatum: surrender your discoveries or face isolation.",
		choices = {
			opt(
				"SUBMIT THE DATA",
				"Lose 5 Knowledge; improve trust.",
				{ knowledge = -5, trust = 8, ethic = "cautious" }
			),
			opt(
				"DEFY THE SENTINEL",
				"+10 Knowledge; relations suffer.",
				{ knowledge = 10, trust = -8, ethic = "bold" }
			),
		},
	},
	refugees_return = {
		title = "A DEBT REPAID",
		context = "chain",
		body = "The rescued captain returns with a convoy of supplies and a message of gratitude.",
		choices = {
			opt(
				"ACCEPT THE SUPPLIES",
				"+9 Alloy and +4 Credits.",
				{ alloy = 9, credits = 4, ethic = "pragmatic" }
			),
			opt(
				"ESTABLISH A SCHOOL",
				"+11 Knowledge and public trust.",
				{ knowledge = 11, trust = 4, ethic = "compassionate" }
			),
		},
	},
}
function E.create(id, system)
	local data = E.catalog[id]
	if not data then
		return nil
	end
	return { id = id, system = system, title = data.title, body = data.body, choices = data.choices }
end
return E
