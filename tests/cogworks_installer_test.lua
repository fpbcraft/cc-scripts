local disk=dofile("tests/support/install_checks.lua")("cogworks")
-- Verify the new modules through the installed loader, not source-tree require.
local api=disk.run('cogworks','--test-api')
local app=api.app.new()
app:enter(1,true)
assert(app.scene=='briefing' and app.briefing.number==1,'Installed mission briefing works')
app:act('beginLevel')
assert(app.scene=='tutorial' and #app.tutorial.steps>0,'Installed Ponder tutorial works')
print('Installed COGWORKS briefing and tutorial dependencies boot successfully')
