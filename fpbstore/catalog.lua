-- FPB Store: explicit allowlisted catalog of supported installable games.
-- To add a game, register its installer, entry point and code-only file list.
-- Never include save files or data folders in managedFiles.
return {
 schema=1,
 storeVersion="1.1.3",
 apps={
  {
   version="1.0.0",id="cogworks",name="COGWORKS",subtitle="KINETIC LAB",
   description="30 tactile Create-inspired machinery puzzles.",
   icon="C",genre="PUZZLE",root="/cogworks",
   entry="/cogworks/main.lua",installer="install-cogworks.lua",
   managedFiles={"main.lua","display.lua","terminal_view.lua","app.lua","storage.lua",
    "engine.lua","levels.lua","expansion.lua","render.lua","README.md"},
   saves={"/cogworks/saves","/cogworks/save.dat","/cogworks/settings.dat"},
  },
  {
   version="2.0.8",id="railbreak",name="RAILBREAK",subtitle="KINETIC FRONTIER",
   description="Run a railway, manage cargo and improve your trains.",
   icon="R",genre="STRATEGY",root="/railbreak",
   entry="/railbreak/main.lua",installer="install-railbreak.lua",
   managedFiles={"main.lua","display.lua","terminal_view.lua","core/util.lua",
    "content/catalog.lua","game/state.lua","game/kinetics.lua",
    "game/processing.lua","game/commands.lua","render/canvas.lua",
    "ui/app.lua","platform/storage.lua","README.md","QUICKSTART.txt",
    "train/catalog.lua","train/state.lua","train/rules.lua",
    "train/render.lua","train/art.lua","train/ui.lua","train/info.lua",
    "train/storage.lua"},
   saves={"/railbreak/data"},
  },
  {
   version="5.6",id="shattered",name="SHATTERED EXPANSE",subtitle="FOUR EMPIRES",
   description="A space 4X with exploration, diplomacy and events.",
   icon="S",genre="4X / RPG",root="/shattered",
   entry="/shattered/shattered.lua",installer="install-shattered.lua",
   managedFiles={"shattered.lua","display.lua","terminal_view.lua",
"expanse-v5/content.lua",
    "expanse-v5/events.lua","expanse-v5/sim.lua",
    "expanse-v5/render.lua","expanse-v5/theme.lua","expanse-v5/ui.lua"},
   saves={"/shattered/v5-save.dat","/shattered/v5-save.dat.bak"},
  },
  {
   version="0.2.0",id="ironspire",name="IRONSPIRE",subtitle="CLOCKWORK ASCENT",
   description="Solo deckbuilding roguelike with card battles and branching routes.",
   icon="I",genre="DECKBUILDER",root="/ironspire",
   entry="/ironspire/main.lua",installer="install-ironspire.lua",
   managedFiles={"main.lua","render.lua","map.lua","README.md"},
   saves={"/ironspire/data"},
  },
  {
   version="0.3.0",id="civcraft",name="CIVCRAFT",subtitle="POCKET CIVILIZATION",
   description="Local hotseat or networked 2-4 player civilization-building 4X.",
   icon="V",genre="4X / STRATEGY",root="/civcraft",
   entry="/civcraft/game.lua",installer="install-civcraft.lua",
   managedFiles={"game.lua","render.lua","ui.lua","hex.lua","icons.lua","README.md"},
   saves={"/civcraft/data"},
  },
 }
}
