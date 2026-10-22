-- Basalt 2.5 touch interface for FPBCRAFT Factory Control.
-- All UI pages are disposable views of the persistent factory core.
local UI={}
local C=colors
local NAV={"OVERVIEW","INVENTORY","SWITCHBOARD","MACHINES",
  "RULES","GRAPHS","POWER GRID","REQUESTS","DIAGNOSTICS","SETTINGS"}
local METRICS={
  {"stress","KINETIC STRESS","%",C.orange},
  {"rpm","SHAFT RPM","RPM",C.cyan},
  {"stock","TOTAL STOCK","items",C.lime},
  {"voltage","VOLTAGE","V",C.yellow},
  {"current","CURRENT","A",C.lightBlue},
  {"power","ELECTRICAL POWER","W",C.red},
  {"battery","BATTERY CHARGE","%",C.green},
  {"energy","ENERGY METER","J",C.purple}
}
local function short(value,n)
  value=tostring(value or "")
  n=math.max(1,n or 16)
  if #value>n then return value:sub(1,n-1).."~" end
  return value
end
local function num(n,places)
  if type(n)~="number" then return "-" end
  return string.format("%."..tostring(places or 1).."f",n)
end
local function matchMetric(s)
  for _,v in ipairs(METRICS) do if v[1]==s then return v end end
  return METRICS[1]
end
function UI.run(core)
  local basalt=require("basalt")
  basalt.use("charts")
  local terminal=basalt.getMainFrame()
  terminal.background=C.black
  local mons={}
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name)=="monitor" then mons[#mons+1]=name end
  end
  table.sort(mons)
  local root=terminal
  local monitorName=mons[1]
  if monitorName then
    local monitor=peripheral.wrap(monitorName)
    monitor.setTextScale(core.config.textScale)
    root=basalt.createFrame(monitor,monitorName)
    root.background=C.black
    terminal:addLabel({x=2,y=2,text="FPBCRAFT FACTORY CONTROL",
      foreground=C.cyan})
    terminal:addLabel({x=2,y=4,width=45,
      text="Use the attached Advanced Monitor to operate."})
    terminal:addLabel({x=2,y=6,width=45,
      text="Press Ctrl+T to exit (outputs retain their states)."})
  end
  local w,h=(monitorName and peripheral.wrap(monitorName) or term).getSize()
  if w<32 or h<16 then
    error("Monitor must be at least 32x16 chars; try text scale 0.5")
  end
  local page="HOME"
  local panel=nil
  local message=""
  local invQuery=""
  local invSort="name"
  local invPage=1
  local machinePage=1
  local genericPage=1
  local graphKey="stress"
  local selected=nil
  local quantity=1
  local selectedMachine=nil
  local confirmAction=nil
  local editor={}
  local editMode="new"
  local editPage=1
  local kbPage=1
  local kb={value="",title="",returnPage="HOME",callback=nil,numeric=false}
  local render
  local function label(parent,x,y,value,color,width)
    if y<1 or y>h-2 then return end
    return parent:addLabel({x=x,y=y,width=width or math.max(1,w-x),
      text=short(value,width or (w-x)),foreground=color or C.white})
  end
  local function button(parent,x,y,width,height,title,action,color)
    if width<3 or y<1 or x<1 or x+width-1>w or y+height-1>h-2 then
      return nil
    end
    local b=parent:addButton({x=x,y=y,width=width,height=height,
      text=short(title,width-1),background=color or C.blue,foreground=C.white})
    b:onClick(action)
    return b
  end
  local function notify(msg)
    message=short(msg,w-4)
    if panel then
      local status=root:find("status_bar")
      if status then status.text=message end
    end
  end
  local function navigateTo(p)
    page=p
    genericPage=1
    render()
  end
  local function fieldInput(title,initial,numeric,callback,back)
    kb={title=title,value=tostring(initial or ""),numeric=numeric or false,
      callback=callback,returnPage=back or page}
    kbPage=1
    page="KEYBOARD"
    render()
  end
  local function choose(target,list,pageNumber,perPage,action,formatter)
    local first=(pageNumber-1)*perPage+1
    for i=0,perPage-1 do
      local entry=list[first+i]
      if not entry then break end
      local y=5+i*2
      button(target,2,y,w-4,1,formatter(entry),function() action(entry) end,C.gray)
    end
    local pages=math.max(1,math.ceil(#list/perPage))
    label(target,math.max(2,w-18),3,("PAGE %d/%d"):format(pageNumber,pages),C.lightGray,16)
    local controlsY=h-4
    if pageNumber>1 then
      button(target,2,controlsY,10,1,"< PREV",function()
        genericPage=genericPage-1
        if page=="INVENTORY" then invPage=genericPage end
        render()
      end)
    end
    if pageNumber<pages then
      button(target,w-11,controlsY,10,1,"NEXT >",function()
        genericPage=genericPage+1
        if page=="INVENTORY" then invPage=genericPage end
        render()
      end)
    end
  end
  local function showHome()
    label(panel,3,3,"SELECT SYSTEM",C.cyan)
    local cols=w>=78 and 4 or w>=56 and 3 or 2
    local rows=math.ceil(#NAV/cols)
    local spacing=1
    local cellw=math.floor((w-4-(cols-1)*spacing)/cols)
    local cellh=math.max(2,math.min(4,math.floor((h-8)/rows)))
    for i,name in ipairs(NAV) do
      local ix=(i-1)%cols
      local iy=math.floor((i-1)/cols)
      local x=2+ix*(cellw+spacing)
      local y=5+iy*cellh
      button(panel,x,y,cellw,math.max(1,cellh-1),name,function()
        navigateTo(name)
      end)
    end
  end
  local function showOverview()
    local snap=core.snapshot
    label(panel,3,3,"KINETIC & LOGISTICS",C.cyan)
    local s=snap.stress[1]
    local percent=s and s.capacity and s.capacity>0 and
      s.used/s.capacity*100 or nil
    label(panel,3,5,"Stress: "..num(percent).."%",C.white)
    label(panel,3,7,"Shaft: "..num(snap.speed[1] and snap.speed[1].rpm).." RPM",C.white)
    local total=0
    for _,i in ipairs(snap.stock) do total=total+i.count end
    label(panel,3,9,snap.stockError or ("Stock: "..total.." items"),C.white)
    label(panel,3,11,"Machines: "..#core.machines,C.white)
    local running=0
    for _,m in ipairs(core.machines) do
      if core:actual(m)==true then running=running+1 end
    end
    label(panel,3,13,"Outputs ON: "..running,C.lime)
    if h>=24 then
      button(panel,3,16,math.min(20,w-5),2,"SWITCHBOARD",function()navigateTo("SWITCHBOARD")end)
      button(panel,3,19,math.min(20,w-5),2,"INVENTORY",function()navigateTo("INVENTORY")end)
    end
  end
  local function showInventory()
    local listing=core:sortedStock(invQuery,invSort)
    label(panel,2,3,("SEARCH: %s"):format(short(invQuery,w-33)),C.cyan,w-27)
    button(panel,w-26,3,9,1,"SEARCH",function()
      fieldInput("Search stock",invQuery,false,function(value)
        invQuery=value;genericPage=1;invPage=1
      end,"INVENTORY")
    end)
    button(panel,w-16,3,7,1,"CLEAR",function()
      invQuery="";invPage=1;render()
    end,C.red)
    button(panel,w-8,3,7,1,"SORT",function()
      invSort=invSort=="name" and "count" or invSort=="count" and "mod" or "name"
      invPage=1;render()
    end)
    local per=math.max(2,math.floor((h-11)/2))
    genericPage=invPage
    choose(panel,listing,invPage,per,function(item)
      selected=item
      quantity=math.min(64,item.count)
      navigateTo("ITEM")
    end,function(item)
      return short(item.displayName or item.name,w-18).."  x"..tostring(item.count)
    end)
    invPage=genericPage
    -- choose() updates genericPage in handlers; keep inventory page synchronized.
    label(panel,2,h-6,("Entries: %d   Sort: %s"):format(#listing,invSort),C.lightGray)
  end
  local function showItem()
    if not selected then return navigateTo("INVENTORY") end
    label(panel,3,3,"PACKAGE ORDER",C.cyan)
    label(panel,3,5,selected.displayName or selected.name,C.white)
    label(panel,3,7,short(selected.name,w-6),C.lightGray)
    label(panel,3,9,"Available: "..selected.count.." | Qty: "..quantity,C.yellow)
    label(panel,3,11,"Destination: "..core.config.hubAddress,C.cyan)
    button(panel,3,13,10,2,"-1",function()
      quantity=math.max(1,quantity-1);render()
    end)
    button(panel,15,13,10,2,"+1",function()
      quantity=math.min(selected.count,core.config.maxOrder,quantity+1);render()
    end)
    if w>=50 then
      button(panel,27,13,10,2,"64",function()
        quantity=math.min(selected.count,core.config.maxOrder,64);render()
      end)
      button(panel,39,13,10,2,"MAX",function()
        quantity=math.min(selected.count,core.config.maxOrder);render()
      end)
    end
    button(panel,3,16,12,2,"QUANTITY",function()
      fieldInput("Order quantity",quantity,true,function(value)
        quantity=math.max(1,math.min(selected.count,core.config.maxOrder,
          math.floor(tonumber(value) or 1)))
      end,"ITEM")
    end)
    button(panel,17,16,math.min(18,w-19),2,"SEND TO HUB",function()
      navigateTo("ORDER CONFIRM")
    end,C.orange)
  end
  local function showConfirmation()
    label(panel,3,4,"CONFIRM CREATE PACKAGE REQUEST",C.yellow)
    label(panel,3,7,short(selected and (selected.displayName or selected.name),w-5))
    label(panel,3,9,("Quantity: %d"):format(quantity))
    label(panel,3,11,"Address: "..core.config.hubAddress)
    button(panel,3,14,16,2,"CONFIRM",function()
      local ok,result=core:request(selected,quantity)
      notify(ok and ("Requested "..result.." items") or ("ERROR: "..result))
      navigateTo("INVENTORY")
    end,C.green)
    button(panel,21,14,12,2,"CANCEL",function()navigateTo("ITEM")end,C.red)
  end
  local function showSwitchboard()
    label(panel,3,3,"SWITCHBOARD  /  TAP TO TOGGLE",C.cyan)
    local per=math.max(2,math.floor((h-11)/2))
    local pages=math.max(1,math.ceil(#core.machines/per))
    genericPage=math.min(genericPage,pages)
    for i=1,per do
      local m=core.machines[(genericPage-1)*per+i]
      if not m then break end
      local y=5+(i-1)*2
      local actual=core:actual(m)
      local state=actual==nil and "?" or actual and "ON" or "OFF"
      local wide=math.max(10,w-24)
      button(panel,2,y,wide,1,short(m.name,wide-5).." ["..state.."]",function()
        selectedMachine=m;navigateTo("MACHINE")
      end,C.gray)
      button(panel,wide+3,y,math.min(18,w-wide-4),1,
        m.mode=="auto" and "AUTO" or actual and "TURN OFF" or "TURN ON",
        function()
          local ok,err=core:toggle(m)
          notify(ok and ("Switched "..m.name) or (err or "Control failed"))
          render()
        end,m.mode=="auto" and C.gray or actual and C.red or C.green)
    end
    if genericPage>1 then button(panel,2,h-4,11,1,"< PREV",function()
      genericPage=genericPage-1;render()
    end) end
    if genericPage<pages then button(panel,w-12,h-4,11,1,"NEXT >",function()
      genericPage=genericPage+1;render()
    end) end
    label(panel,2,h-6,("Page %d/%d; AUTO machines require Manual mode"):format(genericPage,pages),
      C.lightGray)
  end
  local function showMachine()
    local m=selectedMachine
    if not m then return navigateTo("SWITCHBOARD") end
    label(panel,3,3,short(m.name,w-5),C.cyan)
    local state=core:actual(m)
    label(panel,3,5,"State: "..(state==nil and "UNKNOWN" or state and "ON" or "OFF"),
      state==nil and C.orange or state and C.lime or C.red)
    label(panel,3,7,"Mode: "..m.mode:upper())
    label(panel,3,9,"Relay: "..m.device.." / "..m.side)
    label(panel,3,11,"Rate*: "..num(core.rates[m.id]).." / min")
    label(panel,3,12,"Stock: "..short(m.item,math.max(8,w-19)))
    label(panel,3,13,("Stop >=%d, Resume <=%d"):format(m.stopAt,m.resumeBelow))
    if core.errors[m.id] then label(panel,3,14,short(core.errors[m.id],w-5),C.red) end
    button(panel,3,16,12,2,state and "TURN OFF" or "TURN ON",function()
      local ok,err=core:toggle(m)
      notify(ok and "Output updated" or (err or "Error"))
      render()
    end,state and C.red or C.green)
    button(panel,17,16,12,2,m.mode=="manual" and "USE AUTO" or "MANUAL",function()
      local ok,err=core:setMode(m,m.mode=="manual" and "auto" or "manual")
      notify(ok and "Mode updated" or err)
      render()
    end)
    if w>=52 then
      button(panel,31,16,12,2,"EDIT",function()
        editor={}
        for k,v in pairs(m) do editor[k]=v end
        editMode="existing";editPage=1;navigateTo("MACHINE EDIT")
      end)
    end
    if h>=25 then
      label(panel,3,20,"*Stock delta estimate, not counted actual output",C.lightGray)
    end
  end
  local machineFields={
    {"id","ID",false},{"name","NAME",false},{"device","RELAY / computer",false},
    {"side","SIDE",false},{"product","OUTPUT ITEM ID",false},
    {"item","RULE STOCK ITEM",false},{"stopAt","STOP AT",true},
    {"resumeBelow","RESUME BELOW",true},
    {"onSignal","SIGNAL WHEN RUNNING (1=ON)",false}
  }
  local function showMachineEdit()
    label(panel,3,3,editMode=="new" and "REGISTER MACHINE" or "EDIT MACHINE",C.cyan)
    local per=math.max(2,math.floor((h-11)/2))
    local pages=math.max(1,math.ceil(#machineFields/per))
    editPage=math.min(editPage,pages)
    for i=1,per do
      local f=machineFields[(editPage-1)*per+i]
      if not f then break end
      local y=5+(i-1)*2
      button(panel,3,y,w-6,1,f[2]..": "..short(editor[f[1]] or "",w-26),function()
        if f[1]=="onSignal" then
          editor.onSignal=not (editor.onSignal==false)
          render()
          return
        end
        fieldInput(f[2],editor[f[1]],f[3],function(value)
          if f[3] then
            editor[f[1]]=tonumber(value) or 0
          elseif f[1]=="device" or f[1]=="side" or f[1]=="product" or
            f[1]=="item" or f[1]=="id" then
            editor[f[1]]=value:lower()
          else
            editor[f[1]]=value
          end
        end,"MACHINE EDIT")
      end,C.gray)
    end
    label(panel,3,h-6,("Fields page %d/%d"):format(editPage,pages),C.lightGray)
    if editPage>1 then
      button(panel,w-24,h-4,9,1,"< FIELDS",function()
        editPage=editPage-1;render()
      end)
    end
    if editPage<pages then
      button(panel,w-13,h-4,9,1,"FIELDS >",function()
        editPage=editPage+1;render()
      end)
    end
    button(panel,3,h-4,11,1,"SAVE",function()
      local ok,err=core:register(editor)
      if ok then notify("Machine saved");navigateTo("MACHINES")
      else notify(err);render() end
    end,C.green)
    if editMode=="existing" then
      button(panel,16,h-4,11,1,"REMOVE",function()
        local ok,err=core:remove(editor.id)
        notify(ok and "Removed" or err)
        if ok then navigateTo("MACHINES") else render() end
      end,C.red)
    end

  end
  local function showMachines()
    label(panel,3,3,"REGISTERED MACHINES",C.cyan)
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,core.machines,genericPage,per,function(m)
      selectedMachine=m;navigateTo("MACHINE")
    end,function(m) return m.name.." ("..m.device..")" end)
    button(panel,3,h-4,13,1,"+ ADD",function()
      editor={id="",name="",device="computer",side="back",onSignal=true,
        stopAt=0,resumeBelow=0,product="",item=""}
      editMode="new";editPage=1;navigateTo("MACHINE EDIT")
    end,C.green)
  end
  local function showRules()
    label(panel,3,3,"INVENTORY STOCK-BAND RULES",C.cyan)
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,core.machines,genericPage,per,function(m)
      selectedMachine=m;navigateTo("MACHINE")
    end,function(m)
      return short(m.name,w-24).." "..(m.mode=="auto" and "AUTO" or "MAN")
          .." "..m.stopAt.."/"..m.resumeBelow
    end)
    label(panel,3,h-6,"AUTO stops high, resumes low; Manual bypasses rules",C.lightGray)
  end
  local function showGraphs()
    local metric=matchMetric(graphKey)
    label(panel,3,3,metric[2].." ("..metric[3]..")",C.cyan)
    local chartY=6
    local gh=math.max(5,h-14)
    local chart=panel:addPixelGraph({
      x=3,y=chartY,width=w-6,height=gh,
      background=C.black,minValue=0,maxValue=100
    })
    chart:addSeries("data",{color=metric[4],pointCount=math.min(200,(w-6)*2)})
    local mx=0
    for _,point in ipairs(core.samples) do
      local v=point[graphKey]
      if type(v)=="number" then mx=math.max(mx,v) end
    end
    chart.maxValue=math.max(graphKey=="stress" and 100 or graphKey=="battery" and 100 or 10,math.ceil(mx*1.2))
    for _,point in ipairs(core.samples) do
      local v=point[graphKey]
      if type(v)=="number" then chart:addPoint("data",v) end
    end
    local col=math.max(2,math.floor((w-4)/4))
    for i,entry in ipairs(METRICS) do
      local row=math.floor((i-1)/4)
      local x=2+((i-1)%4)*col
      local y=h-6+row
      button(panel,x,y,col-1,1,short(entry[1]:upper(),col-2),function()
        graphKey=entry[1];render()
      end,graphKey==entry[1] and C.purple or C.gray)
    end
    label(panel,3,h-8,("Samples: %d / 360   Max: %s"):format(#core.samples,num(chart.maxValue,0)),C.lightGray)
  end
  local function showPower()
    label(panel,3,3,"CREATE: POWER GRID",C.cyan)
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,core.snapshot.power,genericPage,per,function(p)
      selected=p;navigateTo("POWER DETAIL")
    end,function(p)
      return p.label.." "..short(p.name,w-30).." "..num(p.value).." "..p.unit
    end)
    if #core.snapshot.power==0 then
      label(panel,3,7,"Connect Power Grid gauges via wired modems",C.orange)
    end
  end
  local function showPowerDetail()
    if not selected then return navigateTo("POWER GRID") end
    label(panel,3,3,selected.label,C.cyan)
    label(panel,3,6,"Peripheral: "..selected.name)
    label(panel,3,8,"Value: "..num(selected.value).." "..selected.unit,C.lime)
    label(panel,3,10,"Energy: "..num(selected.energy))
    label(panel,3,12,"Capacity: "..num(selected.capacity))
    label(panel,3,14,"RPM: "..num(selected.rpm).."  Load: "..num(selected.load))
  end
  local function showRequests()
    label(panel,3,3,"PACKAGE REQUEST HISTORY",C.cyan)
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,core.orders,genericPage,per,function(order)
      selected=order;navigateTo("REQUEST DETAIL")
    end,function(order)
      return short(order.item,w-25).." x"..order.quantity.." -> "..order.to
    end)
  end
  local function showRequestDetail()
    if not selected then return navigateTo("REQUESTS") end
    label(panel,3,4,selected.item,C.cyan)
    label(panel,3,6,"Requested: "..selected.requested)
    label(panel,3,8,"Accepted: "..selected.quantity)
    label(panel,3,10,"Address: "..selected.to)
    label(panel,3,12,"Status: "..selected.status,C.orange)
    label(panel,3,14,"Create does not report delivery confirmations",C.lightGray)
  end
  local function showDiagnostics()
    label(panel,3,3,"PERIPHERAL DIAGNOSTICS",C.cyan)
    local names=peripheral.getNames()
    table.sort(names)
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,names,genericPage,per,function(name)
      selected={name=name,kind=peripheral.getType(name)}
      navigateTo("PERIPHERAL DETAIL")
    end,function(name) return name.." ("..tostring(peripheral.getType(name))..")" end)
    if core.snapshot.stockError then
      label(panel,3,h-6,short(core.snapshot.stockError,w-5),C.orange)
    end
  end
  local function showPeripheralDetail()
    label(panel,3,4,selected.name,C.cyan)
    label(panel,3,6,"Type: "..selected.kind)
    local methods=peripheral.getMethods(selected.name) or {}
    table.sort(methods)
    local y=8
    for _,v in ipairs(methods) do
      if y>h-5 then break end
      label(panel,3,y,v,C.lightGray);y=y+1
    end
  end
  local function showSettings()
    label(panel,3,3,"APPLICATION SETTINGS",C.cyan)
    label(panel,3,5,"Factory: "..core.config.site)
    label(panel,3,8,"Hub address: "..core.config.hubAddress)
    label(panel,3,11,"Poll interval: "..core.config.refreshSeconds.."s")
    button(panel,3,6,15,1,"RENAME",function()
      fieldInput("Factory name",core.config.site,false,function(s)
        core:configure({site=s})
      end,"SETTINGS")
    end)
    button(panel,3,9,15,1,"HUB ADDRESS",function()
      fieldInput("Package destination",core.config.hubAddress,false,function(s)
        core:configure({hubAddress=s})
      end,"SETTINGS")
    end)
    button(panel,3,12,15,1,"INTERVAL",function()
      fieldInput("Poll every X seconds",core.config.refreshSeconds,true,function(s)
        core:configure({refreshSeconds=tonumber(s)})
      end,"SETTINGS")
    end)
  end
  local function showKeyboard()
    label(panel,2,3,short(kb.title..": "..kb.value,w-5),C.cyan,w-4)
    local chars=kb.numeric and "1234567890.-" or
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-:. /"
    local cols=math.min(10,math.max(5,math.floor((w-4)/5)))
    local cw=math.max(4,math.floor((w-4)/cols))
    local rows=math.max(1,math.floor((h-12)/2))
    local perPage=cols*rows
    local pages=math.max(1,math.ceil(#chars/perPage))
    kbPage=math.min(kbPage,pages)
    local start=(kbPage-1)*perPage+1
    for pos=1,perPage do
      local index=start+pos-1
      if index>#chars then break end
      local x=2+((pos-1)%cols)*cw
      local y=5+math.floor((pos-1)/cols)*2
      local ch=chars:sub(index,index)
      button(panel,x,y,cw-1,1,ch==" " and "SPACE" or ch,function()
        kb.value=kb.value..ch
        render()
      end,C.gray)
    end
    if pages>1 then
      label(panel,2,h-7,("Keyboard %d/%d"):format(kbPage,pages),C.lightGray)
      if kbPage>1 then button(panel,w-22,h-7,10,1,"< KEYS",function()
        kbPage=kbPage-1;render()
      end) end
      if kbPage<pages then button(panel,w-11,h-7,10,1,"KEYS >",function()
        kbPage=kbPage+1;render()
      end) end
    end
    local y=h-5
    local bw=math.max(6,math.floor((w-8)/4))
    button(panel,2,y,bw,2,"BACKSPACE",function()
      kb.value=kb.value:sub(1,-2);render()
    end,C.orange)
    button(panel,3+bw,y,bw,2,"CLEAR",function()
      kb.value="";render()
    end,C.red)
    button(panel,4+bw*2,y,bw,2,"DONE",function()
      local result=kb.value
      local cb=kb.callback
      local dest=kb.returnPage
      if cb then cb(result) end
      navigateTo(dest)
    end,C.green)
    button(panel,5+bw*3,y,bw,2,"CANCEL",function()
      navigateTo(kb.returnPage)
    end)
  end
  function render()
    local x,y=(monitorName and peripheral.wrap(monitorName) or term).getSize()
    if x~=w or y~=h then w=x;h=y end
    if panel then panel:destroy() end
    panel=root:addFrame({x=1,y=1,width=w,height=h,background=C.black})
    panel:addLabel({x=2,y=1,width=w-3,text=short("FPBCRAFT / "..core.config.site,w-5),
      foreground=C.cyan})
    if page~="HOME" then
      button(panel,2,2,8,1,"< HOME",function()navigateTo("HOME")end,C.gray)
      label(panel,12,2,page,C.yellow)
      if page=="ITEM" then
        button(panel,w-11,2,10,1,"< STOCK",function()navigateTo("INVENTORY")end,C.gray)
      elseif page=="MACHINE" or page=="MACHINE EDIT" then
        button(panel,w-11,2,10,1,"< LIST",function()navigateTo("MACHINES")end,C.gray)
      end
    end
    local actions={
      HOME=showHome,OVERVIEW=showOverview,INVENTORY=showInventory,
      ITEM=showItem,["ORDER CONFIRM"]=showConfirmation,
      SWITCHBOARD=showSwitchboard,MACHINES=showMachines,
      MACHINE=showMachine,["MACHINE EDIT"]=showMachineEdit,
      RULES=showRules,GRAPHS=showGraphs,["POWER GRID"]=showPower,
      ["POWER DETAIL"]=showPowerDetail,REQUESTS=showRequests,
      ["REQUEST DETAIL"]=showRequestDetail,
      DIAGNOSTICS=showDiagnostics,["PERIPHERAL DETAIL"]=showPeripheralDetail,
      SETTINGS=showSettings,KEYBOARD=showKeyboard
    }
    local draw=actions[page] or showHome
    draw()
    panel:addLabel({name="status_bar",x=2,y=h-1,width=w-3,
      text=short(message~="" and message or "FPBCRAFT FACTORY CONTROL",w-4),
      foreground=C.lightGray})
  end
  -- First scan before first draw. Errors do not prevent monitor display.
  local ok,err=pcall(function()core:scan()end)
  if not ok then message="Initial scan error: "..tostring(err) end
  local title=root:addLabel({x=3,y=math.floor(h/2)-1,width=w-5,
    text="FPBCRAFT INDUSTRIAL CONTROL",foreground=C.cyan})
  local subtitle=root:addLabel({x=3,y=math.floor(h/2)+1,width=w-5,
    text="INITIALIZING CONTROL SYSTEM...",foreground=C.lightGray})
  basalt.schedule(function()
    sleep(0.5)
    title:destroy();subtitle:destroy()
    render()
  end)
  basalt.schedule(function()
    while true do
      sleep(core.config.refreshSeconds)
      local scanned,errorMessage=pcall(function()core:scan()end)
      if not scanned then notify("Scan error: "..tostring(errorMessage)) end
      -- Do not interrupt an edit or an on-screen keyboard.
      if page~="KEYBOARD" and page~="MACHINE EDIT" then
        render()
      end
    end
  end)
  basalt.run()
  core:shutdown()
end
return UI
