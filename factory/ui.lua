-- Basalt 2.5 touch interface for FPBCRAFT Factory Control.
-- All UI pages are disposable views of the persistent factory core.
local UI={}
local C=colors
local NAV={"OVERVIEW","INVENTORY","SWITCHBOARD","MACHINES",
  "RULES","GRAPHS","DEVICES","READINGS","POWER GRID","REQUESTS",
  "DIAGNOSTICS","SETTINGS"}
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
local Text=require("ui_text")
local short=Text.clip
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
  local completion=require("completions")
  local layout=require("layout")
  local graphMetrics=require("graph_metrics")
  local ScreenManager=require("screen_manager")
  basalt.use("charts")
  local terminal=basalt.getMainFrame()
  terminal.background=C.black
  local mons={}
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name)=="monitor" or
       (peripheral.hasType and peripheral.hasType(name,"monitor")) then
      local ok,screen=pcall(peripheral.wrap,name)
      if ok and screen and screen.getSize then
        -- The largest connected monitor is the primary control surface.
        -- This avoids selecting a tiny peripheral simply because its
        -- network name sorts before the main factory control monitor.
        if screen.setTextScale then
          pcall(screen.setTextScale,core.config.textScale)
        end
        local measured,mw,mh=pcall(screen.getSize)
        if measured then
          mons[#mons+1]={name=name,area=mw*mh,w=mw,h=mh}
        end
      end
    end
  end
  table.sort(mons,function(a,b)
    if a.area==b.area then return a.name<b.name end
    return a.area>b.area
  end)
  local root=terminal
  local monitorName=mons[1] and mons[1].name or nil
  if monitorName then
    local monitor=peripheral.wrap(monitorName)
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
  local graphPage=1
  local screens -- forward reference for Settings diagnostics
  local selected=nil
  local quantity=1
  local selectedMachine=nil
  local selectedDevice=nil
  local showSystemDevices=false
  local selectedReading=nil
  local confirmAction=nil
  local editor={}
  local editMode="new"
  local editPage=1
  local kbPage=1
  local kb={value="",title="",returnPage="HOME",callback=nil,numeric=false,kind=""}
  local appClipboard=""
  local terminalEditor=nil
  local terminalInput=nil
  local finishField -- shared by touchscreen DONE and computer Enter
  local ensureComputerEditor
  local render
  local function synchronizeTerminal(value)
    if terminalInput and terminalInput.text~=value then terminalInput.text=value end
  end
  local function setKeyboardValue(value)
    kb.value=Text.limit(value,160)
    synchronizeTerminal(kb.value)
    render()
  end
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
    if p~="KEYBOARD" and terminalEditor then
      terminalEditor:destroy()
      terminalEditor=nil
      terminalInput=nil
    end
    render()
  end
  local function fieldInput(title,initial,numeric,callback,back,kind)
    kb={title=title,value=tostring(initial or ""),numeric=numeric or false,
      callback=callback,returnPage=back or page,kind=kind or ""}
    kbPage=1
    page="KEYBOARD"
    ensureComputerEditor()
    render()
    if terminalInput then terminalInput:focus() end
  end
  finishField=function()
    local value=kb.value
    if kb.numeric and value~="" and tonumber(value)==nil then
      notify("Enter a valid number or leave blank")
      return
    end
    local cb,dest=kb.callback,kb.returnPage
    if cb then cb(value) end
    navigateTo(dest)
  end
  ensureComputerEditor=function()
    if not monitorName or terminalEditor then return end
    local tw,th=term.getSize()
    terminalEditor=terminal:addFrame({
      x=1,y=1,width=tw,height=th,background=C.black
    })
    terminalEditor:addLabel({x=2,y=2,width=tw-3,
      text="FACTORY MANAGER / KEYBOARD",foreground=C.cyan})
    terminalEditor:addLabel({x=2,y=4,width=tw-3,
      text="Type or Ctrl+V (Cmd+V on Mac)",foreground=C.lightGray})
    terminalInput=terminalEditor:addInput({
      x=2,y=6,width=math.max(10,tw-4),height=1,
      text=kb.value,maxLength=160,
      background=C.gray,foreground=C.white
    })
    terminalInput:onChange(function(_,value)
      if page~="KEYBOARD" or kb.value==value then return end
      kb.value=value
      render()
    end)
    terminalInput:onEnter(function() finishField() end)
    local done=terminalEditor:addButton({
      x=2,y=9,width=11,height=1,text="APPLY",
      background=C.green,foreground=C.black
    })
    done:onClick(function() finishField() end)
    local cancel=terminalEditor:addButton({
      x=15,y=9,width=11,height=1,text="CANCEL",
      background=C.red,foreground=C.white
    })
    cancel:onClick(function() navigateTo(kb.returnPage) end)
    local copyButton=terminalEditor:addButton({
      x=2,y=11,width=11,height=1,text="COPY",
      background=C.blue,foreground=C.white
    })
    copyButton:onClick(function()
      appClipboard=kb.value
    end)
    local pasteButton=terminalEditor:addButton({
      x=15,y=11,width=11,height=1,text="PASTE",
      background=C.blue,foreground=C.white
    })
    pasteButton:onClick(function()
      if appClipboard~="" then
        setKeyboardValue(kb.value..appClipboard)
        terminalInput:focus()
      end
    end)
    terminalEditor:addLabel({x=2,y=14,width=tw-3,
      text="Copy/Paste buttons use in-app buffer only.",
      foreground=C.lightGray})
    terminalEditor:addLabel({x=2,y=15,width=tw-3,
      text="Suggestions appear on the monitor.",
      foreground=C.lightGray})
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
  -- Chart renderer shared by Graphs, Overview and machine detail views.
  -- Numeric values remain in Core.samples; only the visible window is plotted.
  local function graphNumber(v)
    if type(v)~="number" then return "--" end
    if math.abs(v)>=1e9 then return string.format("%.1fG",v/1e9) end
    if math.abs(v)>=1e6 then return string.format("%.1fM",v/1e6) end
    if math.abs(v)>=1e4 then return string.format("%.1fk",v/1e3) end
    if math.abs(v)>=100 then return string.format("%.0f",v) end
    if math.abs(v)>=10 then return string.format("%.1f",v) end
    return string.format("%.2f",v)
  end
  local function availableMetrics()
    return graphMetrics.available(METRICS,core.snapshot,core.machines,
      core.devices:charts(),C)
  end
  local function collectSeries(key,limit)
    local points={}
    local start=math.max(1,#core.samples-limit+1)
    local first,last,min,max,total=nil,nil,nil,nil,0
    for i=start,#core.samples do
      local item=core.samples[i]
      local value=item[key]
      if type(value)=="number" and value==value and
         value<math.huge and value>-math.huge then
        points[#points+1]=value
        if not first then first=item.time end
        last=item.time
        min=min and math.min(min,value) or value
        max=max and math.max(max,value) or value
        total=total+value
      end
    end
    return points,first,last,min,max,
      #points>0 and total/#points or nil
  end
  local function scaleBounds(min,max)
    if min==nil or max==nil then return 0,100 end
    local low=math.min(0,min)
    local high=math.max(0,max)
    if high==low then high=low+1 end
    local step=(high-low)/4
    local base=10^math.floor(math.log(step)/math.log(10))
    local n=step/base
    local nice=(n<=1 and 1 or n<=2 and 2 or n<=5 and 5 or 10)*base
    local bottom=math.floor(low/nice)*nice
    local top=math.ceil(high/nice)*nice
    if bottom==top then top=bottom+nice end
    return bottom,top
  end
  local function drawChart(parent,metric,x,y,width,height,compact,onOpen)
    if width<21 or height<7 then return end
    local key,title,unit,color=metric[1],metric[2],metric[3],metric[4]
    local titleWidth=onOpen and width-10 or width
    label(parent,x,y,short(title,titleWidth),color,titleWidth)
    if onOpen then
      button(parent,x+width-9,y,9,1,"EXPAND >",onOpen,C.gray)
    end
    local cy=y+2
    local px=x+(compact and 7 or 10)
    local pw=math.max(10,width-(px-x)-1)
    local ph=math.max(3,height-(compact and 5 or 7))
    local values,t0,t1,min,max,avg=collectSeries(key,math.min(200,pw*2))
    local bottom,top=scaleBounds(min,max)
    local latest=values[#values]
    label(parent,x,cy-1,"Now: "..graphNumber(latest).." "..(unit or ""),
      C.lightGray,width)
    local ticks=compact and 2 or 4
    for row=0,ph-1 do
      label(parent,px-2,cy+row,"|",C.gray,1)
    end
    for i=0,ticks do
      local yy=cy+math.floor(i*(ph-1)/ticks)
      label(parent,x,yy,graphNumber(top-(top-bottom)*i/ticks),
        C.lightGray,compact and 5 or 8)
      label(parent,px-2,yy,"+",C.lightGray,1)
    end
    local graph=parent:addPixelGraph({
      x=px,y=cy,width=pw,height=ph,background=C.black,
      minValue=bottom,maxValue=top
    })
    graph:addSeries("data",{color=color,pointCount=math.min(200,pw*2)})
    for _,value in ipairs(values) do graph:addPoint("data",value) end
    if onOpen and graph.onClick then
      graph:onClick(function() onOpen() end)
    end
    if #values==0 then
      label(parent,px+1,cy+math.floor(ph/2),"No data",C.orange,pw-1)
    end
    local ay=cy+ph
    label(parent,px-2,ay,"+",C.lightGray,1)
    label(parent,px,ay,string.rep("-",pw),C.gray,pw)
    label(parent,px,ay,"+",C.lightGray,1)
    label(parent,px+math.floor(pw/2),ay,"+",C.lightGray,1)
    label(parent,px+pw-1,ay,"+",C.lightGray,1)
    if ay+1<=y+height-1 then
      local elapsed=t0 and t1 and math.max(0,t1-t0) or 0
      local window=elapsed>=60 and
        string.format("-%.1fm",elapsed/60) or string.format("-%ds",elapsed)
      label(parent,px,ay+1,window,C.lightGray,math.min(9,pw))
      label(parent,px+pw-4,ay+1,"NOW",C.lightGray,4)
    end
    if not compact then
      local statY=ay+3
      if statY<=y+height-1 then
        label(parent,x,statY,("MIN %s  AVG %s  MAX %s  N=%d"):format(
          graphNumber(min),graphNumber(avg),graphNumber(max),#values),
          C.lightGray,width)
      end
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
    local stress=snap.stress[1]
    local percent=stress and stress.capacity and stress.capacity>0 and
      stress.used/stress.capacity*100 or nil
    label(panel,3,5,"Stress: "..num(percent).."%",C.white)
    label(panel,3,6,"Shaft: "..num(snap.speed[1] and snap.speed[1].rpm).." RPM",C.white)
    local total=0
    for _,item in ipairs(snap.stock) do total=total+item.count end
    label(panel,3,7,snap.stockError or ("Stock: "..total.." items"),C.white)
    local running=0
    for _,m in ipairs(core.machines) do
      if core:actual(m)==true then running=running+1 end
    end
    label(panel,3,8,("Machines: %d    Running: %d"):format(#core.machines,running),
      C.lightGray)
    local alerts={}
    local online=0
    for _,r in ipairs(core.devices.readings) do
      local v=core.devices.values[r.id]
      if v and v.status=="online" then online=online+1 end
      if v and v.warning then alerts[#alerts+1]=r.label..": "..v.warning end
    end
    label(panel,3,9,("Sensors: %d/%d online"):format(
      online,#core.devices.readings),C.lightGray)
    if h>=19 then
      local bw=math.min(17,math.floor((w-8)/3))
      button(panel,3,11,bw,1,"SWITCHBOARD",function()navigateTo("SWITCHBOARD")end)
      button(panel,4+bw,11,bw,1,"INVENTORY",function()navigateTo("INVENTORY")end)
      button(panel,5+2*bw,11,bw,1,"READINGS",function()navigateTo("READINGS")end)
      label(panel,3,13,("Warnings: %d"):format(#alerts),
        #alerts>0 and C.orange or C.lime)
      if alerts[1] then label(panel,3,14,short(alerts[1],w-6),C.orange) end
    end
    -- Do not require a 64-char monitor: on standard 3x2 monitors this
    -- renders short charts BELOW the summary, rather than not rendering.
    local candidates={METRICS[1],METRICS[2],METRICS[3]}
    for _,m in ipairs(core.machines) do
      if m.product and m.product~="" then
        candidates[#candidates+1]={
          "rate_"..m.id,m.name.." / RATE","items/min",C.pink}
      end
    end
    for _,r in ipairs(core.devices:charts()) do
      candidates[#candidates+1]={r.id,r.label,r.unit,C.magenta}
    end
    for _,tile in ipairs(layout.overviewCharts(w,h,#candidates)) do
      local item=candidates[tile.index]
      drawChart(panel,item,tile.x,tile.y,tile.width,tile.height,true,function()
        graphKey=item[1];navigateTo("GRAPH DETAIL")
      end)
    end
  end
  local function showInventory()
    local listing=core:sortedStock(invQuery,invSort)
    label(panel,2,3,("SEARCH: %s"):format(short(invQuery,w-33)),C.cyan,w-27)
    button(panel,w-26,3,9,1,"SEARCH",function()
      fieldInput("Search stock",invQuery,false,function(value)
        invQuery=value;genericPage=1;invPage=1
      end,"INVENTORY","search")
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
      end,"ITEM","quantity")
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
        m.mode=="auto" and "AUTO" or
          actual==nil and "SAFE OFF" or actual and "TURN OFF" or "TURN ON",
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
    if m.device:sub(1,7)=="remote:" then
      local id=tonumber(m.device:match("^remote:(%d+):"))
      if core.remote.errors[id] then
        label(panel,3,10,short(core.remote.errors[id],w-6),C.orange)
      end
    end
    local smoothing=m.rateWindowSeconds or core.config.rateWindowSeconds
    label(panel,3,11,("Smoothed net gain: %s/min (%.0fs avg)"):format(
      num(core.rates[m.id]),smoothing))
    local function stockLine(y,prefix,item)
      if not item or item=="" then
        label(panel,3,y,prefix..": not configured",C.lightGray)
        return
      end
      local count,name,status=core:stockFor(item)
      local value=count~=nil and ("x"..tostring(count)) or
        status=="unavailable" and "unavailable" or "n/a"
      local maxName=math.max(6,w-#prefix-#value-12)
      label(panel,3,y,prefix..": "..short(name or item,maxName).."  "..value,
        count~=nil and C.white or C.orange)
    end
    stockLine(12,"Target",m.item)
    if m.product and m.product~="" and m.product~=m.item then
      stockLine(13,"Output",m.product)
    elseif m.product==m.item and m.product~="" then
      label(panel,3,13,"Output: same as target",C.lightGray)
    else
      label(panel,3,13,"Output: not configured",C.lightGray)
    end
    label(panel,3,14,("Stop >=%d, Resume <=%d"):format(m.stopAt,m.resumeBelow))
    if core.errors[m.id] then
      label(panel,3,15,short(core.errors[m.id],w-5),C.red)
    end
    button(panel,3,16,12,2,state==nil and "SAFE OFF" or state and "TURN OFF" or "TURN ON",function()
      local ok,err=core:toggle(m)
      notify(ok and "Output updated" or (err or "Error"))
      render()
    end,state and C.red or C.green)
    -- Quick rate averaging presets; the editor supports custom 15-900 s.
    if m.product and m.product~="" and w>=44 and h>=27 then
      local options={{30,"30s"},{60,"1m"},{120,"2m"},
        {300,"5m"},{600,"10m"}}
      local bw=math.floor((w-6)/#options)
      for i,preset in ipairs(options) do
        local seconds,text=preset[1],preset[2]
        local x=3+(i-1)*bw
        button(panel,x,19,bw-1,1,text,function()
          local ok,err=core:setRateWindow(m,seconds)
          notify(ok and ("Average window: "..text) or (err or "Invalid window"))
          render()
        end,smoothing==seconds and C.purple or C.gray)
      end
    end
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
      label(panel,3,21,"*Estimated net stock gain; select averaging window above",C.lightGray)
    end
    if h>=34 and w>=32 then
      if m.product and m.product~="" then
        local metric={"rate_"..m.id,
          "PRODUCTION: "..m.name.." / SMOOTHED NET RATE","items/min",C.pink}
        drawChart(panel,metric,3,23,w-6,h-27,true,function()
          graphKey=metric[1];navigateTo("GRAPH DETAIL")
        end)
      else
        label(panel,3,24,
          "Set OUTPUT ITEM ID to enable rate tracking",C.orange,w-5)
      end
    end
  end
  local machineFields={
    {"id","ID",false},{"name","NAME",false},{"device","RELAY / computer",false},
    {"side","SIDE",false},{"product","OUTPUT ITEM ID",false},
    {"rateWindowSeconds","RATE AVG SECONDS",true},
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
        end,"MACHINE EDIT",f[1])
      end,C.gray)
    end
    if h>=19 then
      label(panel,3,h-7,"Remote control: pair the node in Devices first",
        C.lightGray,w-5)
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
        stopAt=0,resumeBelow=0,product="",item="",
        rateWindowSeconds=core.config.rateWindowSeconds}
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
  local function showGraphPicker()
    label(panel,3,3,"SELECT GRAPH METRIC",C.cyan)
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,availableMetrics(),genericPage,per,function(entry)
      graphKey=entry[1];navigateTo("GRAPH DETAIL")
    end,function(entry)
      return short(entry[2],w-12).." ("..entry[3]..")"
    end)
  end
  local function showGraphs()
    local metrics=availableMetrics()
    label(panel,3,3,("LIVE GRAPHS  /  %d METRICS"):format(#metrics),C.cyan)
    local grid=layout.graphGrid(w,h,#metrics,graphPage)
    graphPage=grid.page
    local pages=grid.pages
    for _,tile in ipairs(grid.tiles) do
      local metric=metrics[tile.index]
      drawChart(panel,metric,tile.x,tile.y,tile.width,tile.height,true,function()
        graphKey=metric[1]
        navigateTo("GRAPH DETAIL")
      end)
    end
    local y=h-4
    if graphPage>1 then
      button(panel,2,y,10,1,"< PREV",function()
        graphPage=graphPage-1;render()
      end)
    end
    label(panel,math.floor(w/2)-8,y,
      ("PAGE %d/%d"):format(graphPage,pages),C.lightGray,16)
    if graphPage<pages then
      button(panel,w-11,y,10,1,"NEXT >",function()
        graphPage=graphPage+1;render()
      end)
    end
  end
  local function showGraphDetail()
    local chosen
    for _,item in ipairs(availableMetrics()) do
      if item[1]==graphKey then chosen=item;break end
    end
    if not chosen then
      label(panel,3,5,"Metric unavailable: "..graphKey,C.orange)
      return
    end
    button(panel,w-15,3,13,1,"< ALL GRAPHS",function()
      navigateTo("GRAPHS")
    end,C.gray)
    local rateId=graphKey:match("^rate_(.+)$")
    local chartTop=5
    if rateId then
      for _,m in ipairs(core.machines) do
        if m.id==rateId then
          local options={{30,"30s"},{60,"1m"},{120,"2m"},
            {300,"5m"},{600,"10m"}}
          local bw=math.floor((w-5)/5)
          for i,preset in ipairs(options) do
            local seconds,text=preset[1],preset[2]
            button(panel,2+(i-1)*bw,5,bw-1,1,text,function()
              local ok,err=core:setRateWindow(m,seconds)
              notify(ok and ("Average window: "..text) or err)
              render()
            end,(m.rateWindowSeconds or core.config.rateWindowSeconds)==seconds
              and C.purple or C.gray)
          end
          chartTop=7
          break
        end
      end
    end
    drawChart(panel,chosen,2,chartTop,w-4,h-chartTop-6,false,nil)
  end
  local function showDevices()
    local devices={}
    local ignored={monitor=true,modem=true,computer=true,drive=true,
      printer=true,disk_drive=true}
    for _,dev in ipairs(core.devices:list()) do
      if showSystemDevices or not ignored[dev.type] then
        devices[#devices+1]=dev
      end
    end
    label(panel,3,3,"WIRED PERIPHERALS  /  AUTO DISCOVERY",C.cyan,w-27)
    button(panel,w-24,3,11,1,showSystemDevices and "FACTORY" or "SHOW ALL",function()
      showSystemDevices=not showSystemDevices
      genericPage=1;render()
    end,C.gray)
    button(panel,w-12,3,10,1,"RESCAN",function()
      core.devices:discover();render()
    end)
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,devices,genericPage,per,function(device)
      selectedDevice=device.name
      navigateTo("DEVICE")
    end,function(device)
      local status=device.online and "ON" or
        device.typeMismatch and "TYPE?" or "OFF"
      return short(device.alias or device.name,w-20).." ["..status.."]"
    end)
    if #devices==0 then
      label(panel,3,7,"Attach wired modems and peripherals",C.orange)
    end
    local nodeCount=0
    for _,node in pairs(core.remote.nodes) do
      if core.remote:online(node) then nodeCount=nodeCount+1 end
    end
    label(panel,3,h-6,
      ("Local + remote peripherals | %d remote node(s)"):format(nodeCount),
      C.lightGray)
    if not core.remote.opened and h>=20 then
      label(panel,3,h-8,"Attach Wireless/Ender Modem to this computer",C.orange)
    end
  end
  local function showDevice()
    local dev=core.devices:get(selectedDevice)
    if not dev then return navigateTo("DEVICES") end
    label(panel,3,3,short(dev.alias or dev.name,w-6),C.cyan)
    label(panel,3,5,"Type: "..short(dev.type,w-10))
    label(panel,3,7,"Network: "..short(dev.name,w-13),C.lightGray)
    label(panel,3,9,"Status: "..(dev.online and "CONNECTED" or
      dev.typeMismatch and "TYPE CHANGED" or "OFFLINE"),
      dev.online and C.lime or C.orange)
    label(panel,3,11,"Tracked readings: "..dev.readingCount)
    local remoteId=tonumber(dev.name:match("^remote:(%d+):"))
    local paired=remoteId and core.remote:paired(remoteId)
    if remoteId then
      label(panel,3,12,paired and "Wireless node: PAIRED"
        or "Wireless node: PAIR FOR CONTROL",paired and C.lime or C.orange)
      button(panel,3,16,math.min(20,w-5),1,"PAIR NODE",function()
        fieldInput("Pair key shown on remote computer","",false,
          function(code)
            local ok,err=core.remote:pair(remoteId,code)
            notify(err or (ok and "Pairing requested" or "Pairing failed"))
          end,"DEVICE","pairing")
      end,C.orange)
      if w>=42 then
        button(panel,24,16,math.min(18,w-26),1,"PAIR FROM DISK",function()
          local ok,status=core.remote:pairFromDisk(remoteId)
          notify(status or (ok and "Pairing requested" or "Pairing failed"))
          render()
        end,C.blue)
      end
    end
    button(panel,3,13,math.min(17,w-5),2,"RENAME",function()
      fieldInput("Device name",dev.alias,false,function(value)
        local ok,err=core.devices:rename(dev.name,value)
        notify(ok and "Device renamed" or err)
      end,"DEVICE")
    end)
    if dev.online then
      button(panel,21,13,math.min(21,w-23),2,"ADD READING",function()
        navigateTo("DEVICE METHODS")
      end,C.green)
    end
    if dev.online and (dev.type=="redstone_relay" or
       dev.type=="remote_computer") and (not remoteId or paired) and h>=23 then
      button(panel,3,18,math.min(23,w-5),1,"REGISTER AS MACHINE",function()
        editor={id="",name=dev.alias,device=dev.name,side="front",
          onSignal=true,stopAt=0,resumeBelow=0,item="",product="",
          rateWindowSeconds=core.config.rateWindowSeconds}
        editMode="new";editPage=1;navigateTo("MACHINE EDIT")
      end,C.green)
    end
    if h>24 then
      label(panel,3,21,"To replace a device, relink each reading.",C.lightGray)
      label(panel,3,22,"Only paired remote nodes accept commands.",C.lightGray)
    end
  end
  local function showMethods()
    label(panel,3,3,"READ-ONLY METHOD SELECTION",C.cyan)
    local methods=core.devices:methods(selectedDevice)
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,methods,genericPage,per,function(method)
      local reading,err=core.devices:add(selectedDevice,method)
      if reading then selectedReading=reading.id;navigateTo("READING")
      else notify(err);render() end
    end,function(method) return method.."()" end)
    if #methods==0 then
      label(panel,3,7,"No recognized scalar getters; see Diagnostics",C.orange)
    end
    label(panel,3,h-6,"Only zero-argument read methods are offered",C.lightGray)
  end
  local function showReadings()
    label(panel,3,3,"CONFIGURED TELEMETRY / READINGS",C.cyan)
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,core.devices.readings,genericPage,per,function(r)
      selectedReading=r.id;navigateTo("READING")
    end,function(r)
      local v=core.devices.values[r.id]
      local value=v and v.value
      local status=v and v.status=="online" and
        short(tostring(value),10) or "OFFLINE"
      return short(r.label,w-22).." ["..status.."]"
    end)
    if #core.devices.readings==0 then
      label(panel,3,7,"DEVICES > select a peripheral > ADD READING",C.orange)
    end
  end
  local function showReading()
    local r=core.devices:getReading(selectedReading)
    if not r then return navigateTo("READINGS") end
    local v=core.devices.values[r.id] or {}
    label(panel,3,3,short(r.label,w-6),C.cyan)
    label(panel,3,5,"Device: "..short(r.device,w-13),C.lightGray)
    label(panel,3,7,"Method: "..r.method.."()",C.lightGray)
    local displayed=v.value
    if displayed==nil then displayed="-" end
    label(panel,3,9,"Reading: "..short(tostring(displayed).." "..r.unit,w-13),
      v.status=="online" and C.lime or C.orange)
    label(panel,3,11,"Status: "..tostring(v.status or "Pending"),C.lightGray)
    if v.warning then label(panel,3,12,"ALERT: "..v.warning,C.orange) end
    if h<26 then
      button(panel,3,13,math.min(22,w-6),1,"READING OPTIONS",function()
        navigateTo("READING OPTIONS")
      end)
      return
    end
    local width=math.min(17,math.floor((w-8)/2))
    button(panel,3,14,width,1,"RENAME",function()
      fieldInput("Reading label",r.label,false,function(value)
        local ok,err=core.devices:update(r.id,{label=value})
        notify(ok and "Saved" or err)
      end,"READING")
    end)
    button(panel,4+width,14,width,1,"UNIT: "..(r.unit=="" and "-" or r.unit),function()
      fieldInput("Unit (e.g. RPM, SU, W)",r.unit,false,function(value)
        local ok,err=core.devices:update(r.id,{unit=value})
        notify(ok and "Saved" or err)
      end,"READING")
    end)
    button(panel,3,16,width,1,r.graph and "GRAPH: ON" or "GRAPH: OFF",function()
      core.devices:update(r.id,{graph=not r.graph});render()
    end)
    button(panel,4+width,16,width,1,r.enabled and "POLL: ON" or "POLL: OFF",function()
      core.devices:update(r.id,{enabled=not r.enabled});render()
    end)
    button(panel,3,18,width,1,"WARN ABOVE",function()
      fieldInput("Alert above (blank=off)",r.warnAbove or "",true,function(value)
        local ok,err=core.devices:update(r.id,{warnAbove=
          value=="" and false or tonumber(value)})
        notify(ok and "Saved" or err)
      end,"READING")
    end)
    button(panel,4+width,18,width,1,"WARN BELOW",function()
      fieldInput("Alert below (blank=off)",r.warnBelow or "",true,function(value)
        local ok,err=core.devices:update(r.id,{warnBelow=
          value=="" and false or tonumber(value)})
        notify(ok and "Saved" or err)
      end,"READING")
    end)
    if h>=26 then
      button(panel,3,21,width,1,"RELINK",function()
        navigateTo("RELINK READING")
      end,C.orange)
      button(panel,4+width,21,width,1,"REMOVE",function()
        navigateTo("DELETE READING")
      end,C.red)
    end
  end
  local function showReadingOptions()
    local r=core.devices:getReading(selectedReading)
    if not r then return navigateTo("READINGS") end
    label(panel,3,3,"READING OPTIONS: "..short(r.label,w-23),C.cyan)
    local options={"RENAME","UNIT","TOGGLE GRAPH","TOGGLE POLL",
      "WARN ABOVE","WARN BELOW","RELINK","REMOVE"}
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,options,genericPage,per,function(option)
      if option=="RENAME" then
        fieldInput("Reading label",r.label,false,function(value)
          local ok,err=core.devices:update(r.id,{label=value})
          notify(ok and "Saved" or err)
        end,"READING")
      elseif option=="UNIT" then
        fieldInput("Unit",r.unit,false,function(value)
          local ok,err=core.devices:update(r.id,{unit=value})
          notify(ok and "Saved" or err)
        end,"READING")
      elseif option=="TOGGLE GRAPH" then
        core.devices:update(r.id,{graph=not r.graph})
        navigateTo("READING")
      elseif option=="TOGGLE POLL" then
        core.devices:update(r.id,{enabled=not r.enabled})
        navigateTo("READING")
      elseif option=="WARN ABOVE" or option=="WARN BELOW" then
        local key=option=="WARN ABOVE" and "warnAbove" or "warnBelow"
        fieldInput("Alert threshold (blank disables)",r[key] or "",true,function(value)
          local change={}
          change[key]=value=="" and false or tonumber(value)
          local ok,err=core.devices:update(r.id,change)
          notify(ok and "Saved" or err)
        end,"READING")
      elseif option=="RELINK" then
        navigateTo("RELINK READING")
      elseif option=="REMOVE" then
        navigateTo("DELETE READING")
      end
    end,function(value) return value end)
  end
  local function showRelink()
    local r=core.devices:getReading(selectedReading)
    if not r then return navigateTo("READINGS") end
    label(panel,3,3,"RELINK READING TO SAME DEVICE TYPE",C.cyan)
    local candidates={}
    for _,d in ipairs(core.devices:list()) do
      if d.online and d.type==r.type then candidates[#candidates+1]=d end
    end
    local per=math.max(2,math.floor((h-11)/2))
    choose(panel,candidates,genericPage,per,function(d)
      local ok,err=core.devices:rebind(r.id,d.name)
      notify(ok and "Rebound to "..d.name or err)
      if ok then navigateTo("READING") else render() end
    end,function(d)
      return d.alias.." ("..d.name..")"
    end)
  end
  local function showDeleteReading()
    local r=core.devices:getReading(selectedReading)
    if not r then return navigateTo("READINGS") end
    label(panel,3,5,"REMOVE THIS READING?",C.orange)
    label(panel,3,7,short(r.label,w-7))
    label(panel,3,9,"This will not disconnect the device.",C.lightGray)
    button(panel,3,12,16,2,"REMOVE",function()
      core.devices:remove(r.id);navigateTo("READINGS")
    end,C.red)
    button(panel,21,12,14,2,"CANCEL",function()
      navigateTo("READING")
    end)
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
    label(panel,3,14,"Default rate smoothing: "..
      core.config.rateWindowSeconds.."s")
    if h>=23 then
      local count,errors=screens:status()
      label(panel,3,18,("Secondary displays: %d connected"):format(count),
        count>0 and C.lime or C.orange,w-6)
      if errors[1] then
        label(panel,3,19,short("Display error: "..errors[1],w-6),
          C.orange,w-6)
      end
      if h>=25 then
        button(panel,3,21,18,1,"RESCAN DISPLAYS",function()
          local found=screens:discover()
          screens:refresh()
          notify(("Detected %d secondary display(s)"):format(found))
          render()
        end,C.blue)
      end
    end
    button(panel,3,6,15,1,"RENAME",function()
      fieldInput("Factory name",core.config.site,false,function(s)
        core:configure({site=s})
      end,"SETTINGS","site")
    end)
    button(panel,3,9,15,1,"HUB ADDRESS",function()
      fieldInput("Package destination",core.config.hubAddress,false,function(s)
        core:configure({hubAddress=s})
      end,"SETTINGS","hubAddress")
    end)
    button(panel,3,12,15,1,"INTERVAL",function()
      fieldInput("Poll every X seconds",core.config.refreshSeconds,true,function(s)
        core:configure({refreshSeconds=tonumber(s)})
      end,"SETTINGS","refreshSeconds")
    end)
    button(panel,3,15,15,1,"RATE AVERAGE",function()
      fieldInput("Default rate average (seconds)",
        core.config.rateWindowSeconds,true,function(value)
        local n=tonumber(value)
        if n then core:configure({rateWindowSeconds=n}) end
      end,"SETTINGS","rateWindowSeconds")
    end)
  end
  local function showKeyboard()
    label(panel,2,3,short(kb.title..": "..kb.value,w-5),
      C.cyan,w-4)
    label(panel,2,4,"TYPE ON COMPUTER / Ctrl+V, OR USE TOUCH KEYS",
      C.lightGray,w-4)
    local suggestions=completion.suggest(kb.kind,kb.value,core,
      h>=23 and 3 or 1,editor)
    for i,entry in ipairs(suggestions) do
      local y=4+i
      button(panel,2,y,w-4,1,"USE: "..short(entry.label,w-12),function()
        setKeyboardValue(entry.value)
      end,C.gray)
    end
    local chars=kb.numeric and "1234567890.-" or
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-:. /"
    local cols=math.min(10,math.max(5,math.floor((w-4)/5)))
    local cw=math.max(4,math.floor((w-4)/cols))
    local sy=6+#suggestions
    local rows=math.min(6,math.max(1,math.floor((h-12-sy)/2)))
    local perPage=cols*rows
    local pages=math.max(1,math.ceil(#chars/perPage))
    kbPage=math.min(kbPage,pages)
    local start=(kbPage-1)*perPage+1
    for pos=1,perPage do
      local index=start+pos-1
      if index>#chars then break end
      local x=2+((pos-1)%cols)*cw
      local y=sy+math.floor((pos-1)/cols)*2
      local ch=chars:sub(index,index)
      button(panel,x,y,cw-1,1,ch==" " and "SPACE" or ch,function()
        setKeyboardValue(kb.value..ch)
      end,C.gray)
    end
    if pages>1 then
      local py=h-9
      if kbPage>1 then button(panel,2,py,9,1,"< KEYS",function()
        kbPage=kbPage-1;render()
      end) end
      label(panel,13,py,("Keys %d/%d"):format(kbPage,pages),C.lightGray,12)
      if kbPage<pages then button(panel,w-11,py,10,1,"KEYS >",function()
        kbPage=kbPage+1;render()
      end) end
    end
    if h>=19 then
      button(panel,2,h-7,math.min(12,math.floor(w/3)),1,
        "COPY",function()
          appClipboard=kb.value
          notify("Copied within Factory Manager")
        end,C.blue)
      button(panel,15,h-7,math.min(12,math.floor(w/3)),1,
        "PASTE",function()
          if appClipboard~="" then
            setKeyboardValue(kb.value..appClipboard)
          else notify("No saved app clipboard text") end
        end,C.blue)
    end
    local y=h-5
    local bw=math.max(6,math.floor((w-8)/4))
    button(panel,2,y,bw,2,"BACKSPACE",function()
      setKeyboardValue(kb.value:sub(1,-2))
    end,C.orange)
    button(panel,3+bw,y,bw,2,"CLEAR",function()
      setKeyboardValue("")
    end,C.red)
    button(panel,4+bw*2,y,bw,2,"DONE",function()
      finishField()
    end,C.green)
    button(panel,5+bw*3,y,bw,2,"CANCEL",function()
      navigateTo(kb.returnPage)
    end)
    -- Standalone computers without an Advanced Monitor have an editable
    -- input too. No full panel rebuild inside onChange: focus remains intact.
    if not monitorName then
      local edit=panel:addInput({
        x=2,y=math.min(5,h-11),width=w-4,text=kb.value,
        maxLength=160,background=C.lightGray,foreground=C.black
      })
      edit:onChange(function(_,value) kb.value=value end)
      edit:onEnter(function() finishField() end)
      edit:focus()
    end
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
      RULES=showRules,GRAPHS=showGraphs,["GRAPH DETAIL"]=showGraphDetail,
      ["GRAPH PICKER"]=showGraphPicker,
      DEVICES=showDevices,DEVICE=showDevice,
      ["DEVICE METHODS"]=showMethods,READINGS=showReadings,READING=showReading,
      ["READING OPTIONS"]=showReadingOptions,
      ["RELINK READING"]=showRelink,["DELETE READING"]=showDeleteReading,
      ["POWER GRID"]=showPower,
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
  -- Independently navigable monitors and CC: Terminals; all read from
  -- the one factory automation core. Detection/paint errors are visible.
  screens=ScreenManager.new(core,availableMetrics,monitorName)
  screens:discover()
  basalt.schedule(function()
    while true do
      local event,a,b,c,d=os.pullEvent()
      screens:handle(event,a,b,c,d)
    end
  end)
  -- Background read-only radio receiver. Nodes broadcast automatically;
  -- no manual hub address or node ID configuration is required.
  basalt.schedule(function()
    core.remote:serve()
  end)
  basalt.schedule(function()
    while true do
      sleep(core.config.refreshSeconds)
      local scanned,errorMessage=pcall(function()core:scan()end)
      screens:refresh()
      if not scanned then notify("Scan error: "..tostring(errorMessage)) end
      -- Do not interrupt an edit or an on-screen keyboard.
      if page~="KEYBOARD" and page~="MACHINE EDIT" then
        render()
      end
    end
  end)
  local worked,err=xpcall(function()basalt.run()end,debug.traceback)
  core:shutdown()
  if not worked then error(err,0) end
end
return UI
