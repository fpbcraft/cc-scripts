-- FPB Store: explicit allowlisted catalog of supported installable games.
-- To add a game, register its installer, entry point and code-only file list.
-- Never include save files or data folders in managedFiles.
return {
 schema=1,
 apps={
  {
   id="cogworks",name="COGWORKS",subtitle="KINETIC LAB",
   description="30 tactile Create-inspired machinery puzzles.",
   icon="C",genre="PUZZLE",root="/cogworks",
   entry="/cogworks/main.lua",installer="install-cogworks.lua",
   managedFiles={"main.lua","display.lua","terminal_view.lua","app.lua","storage.lua",
    "engine.lua","levels.lua","expansion.lua","render.lua","README.md"},
   saves={"/cogworks/saves","/cogworks/save.dat","/cogworks/settings.dat"},
  },
  {
   id="railbreak",name="RAILBREAK",subtitle="KINETIC FRONTIER",
   description="Run a railway, manage cargo and improve your trains.",
   icon="R",genre="STRATEGY",root="/railbreak",
   entry="/railbreak/main.lua",installer="install-railbreak.lua",
   managedFiles={"main.lua","display.lua","terminal_view.lua","core/util.lua",
    "content/catalog.lua","game/state.lua","game/kinetics.lua",
    "game/processing.lua","game/commands.lua","render/canvas.lua",
    "ui/app.lua","platform/storage.lua","README.md","QUICKSTART.txt",
    "classic.lua","train/catalog.lua","train/state.lua","train/rules.lua",
    "train/render.lua","train/art.lua","train/ui.lua","train/info.lua",
    "train/storage.lua"},
   saves={"/railbreak/data"},
  },
  {
   id="tidebound",name="TIDEBOUND",subtitle="SHATTERED EXPANSE",
   description="A space 4X with exploration, diplomacy and events.",
   icon="T",genre="4X / RPG",root="/tidebound",
   entry="/tidebound/tidebound.lua",installer="install-tidebound.lua",
   managedFiles={"tidebound.lua","display.lua","terminal_view.lua",
    "tidebound-shattered-v4.lua","tidebound-stellar-frontier.lua",
    "tidebound-kingdoms.lua","tidebound-classic.lua",
    "expanse/content.lua","expanse/events.lua","expanse/sim.lua",
    "expanse/render.lua","expanse/ui.lua","expanse-v5/content.lua",
    "expanse-v5/events.lua","expanse-v5/sim.lua",
    "expanse-v5/render.lua","expanse-v5/ui.lua"},
   saves={"/tidebound/v5-save.dat","/tidebound/v5-save.dat.bak"},
  },
 }
}
