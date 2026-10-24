local H=dofile('tests/support/craftos.lua')
return function(id)
 local spec=dofile('lib/fpb/packages.lua').packages[id]
 local disk=H.new()
 local data=spec.data[1]
 if id=='node'then disk.seed(spec.legacy..'/'..data,'{key="pairing secret",name="Original"}')
 elseif id=='fpbstore'then disk.seed(spec.legacy..'/installed/cogworks.dat','{version="1.0.0"}')
 elseif data=='data' or data=='saves'then disk.seed(spec.legacy..'/'..data..'/test.dat','ORIGINAL DATA')
 else disk.seed(spec.legacy..'/'..data,'ORIGINAL DATA')end
 local relative=(data=='data' or data=='saves') and data..'/test.dat' or
  (id=='fpbstore' and 'installed/cogworks.dat' or data)
 local original=disk.files[spec.legacy..'/'..relative]
 disk.install(id,'main','--no-startup')
 for _,file in ipairs(spec.files)do assert(disk.files[spec.root..'/'..file],id..': missing '..file)end
 for _,name in ipairs(spec.libraries)do assert(disk.files[spec.root..'/_lib/fpb/'..name..'.lua'])end
 assert(disk.files[spec.root..'/'..relative]==original,'Data migrated')
 assert(disk.files[spec.legacy..'/'..relative]==original,'Original retained')
 assert(not disk.files['/startup.lua'],'No forced startup')
 disk.files[spec.root..'/'..relative]='NEWER DATA'
 disk.install(id,'main','--no-startup')
 assert(disk.files[spec.root..'/'..relative]=='NEWER DATA','Repeat install never reimports old data')
 local entry=disk.files[spec.root..'/'..spec.entry]
 disk.failDownload=spec.source..'/'..spec.files[1]
 assert(not pcall(disk.install,id,'main','--no-startup'),'Download failure rejected')
 assert(disk.files[spec.root..'/'..spec.entry]==entry,'No replacement after download failure')
 disk.failDownload=nil
 if not spec.lowDisk then
  disk.failMove=spec.root..'/.install-next/'..spec.files[2]
  assert(not pcall(disk.install,id,'main','--no-startup'),'Move failure rejected')
  assert(disk.files[spec.root..'/'..spec.entry]==entry,'Activation rolled back')
  assert(disk.files[spec.root..'/'..relative]=='NEWER DATA','Rollback retains data')
  disk.failMove=nil
 end
 disk.seed('/startup.lua',"print('unrelated')\n")
 if spec.lowDisk then
  assert(not pcall(disk.install,id,'main','--startup'),'Unrelated startup rejected')
 else disk.install(id,'main','--startup')end
 assert(disk.files['/startup.lua']=="print('unrelated')\n",'Unrelated startup retained')
 disk.files['/startup.lua']="shell.run('"..spec.legacy..'/'..spec.entry.."')\n"
 disk.install(id,'main','--startup')
 assert(disk.files['/startup.lua']:find(spec.root..'/'..spec.entry,1,true),'Owned startup migrated')
 -- Conflicting data must fail before any code is installed.
 local conflict=H.new()
 conflict.seed(spec.legacy..'/'..relative,'OLD')
 conflict.seed(spec.root..'/'..relative,'NEW')
 local ok,err=pcall(conflict.install,id,'main','--no-startup')
 assert(not ok and tostring(err):find('Migration conflict',1,true),'Conflicting data rejected')
 assert(not conflict.files[spec.root..'/'..spec.entry],'Conflict does not activate code')
 assert(conflict.files[spec.root..'/'..relative]=='NEW','Conflict preserves destination')
 print(id..': real bootstrap, bundled dependencies, migration, repeat updates, failures and startup passed')
 return disk
end
