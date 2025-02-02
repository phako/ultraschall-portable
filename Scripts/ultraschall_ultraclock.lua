--[[
################################################################################
#
# Copyright (c) 2014-present Ultraschall (http://ultraschall.fm)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
################################################################################
]]

-- Ultraschall 5.1 - Changelog - Meo-Ada Mespotine
-- * Retina/HiDPI support(requires Ultraschall 4.0 Theme installed or a theme with a line:
--    "layout_dpi_translate  'Ultraschall 2 TCP'    1.74  'Ultraschall 2 TCP Retina'"
--   included, so the clock automatically knows, if your device is Retina/HiDPI-ready.)
-- * Date moved to the right
-- * WriteCenteredText() renamed to WriteAlignedText() has now more options that align text to right or left as well
--    Parameters:
--       text - the text to display
--       color - the color in which to display
--       font - the font-style in which to display
--       size - the size of the font
--       y - the y-position of the text
--       offset - nil or 0, center text
--              1, aligned left
--              2, aligned right
--              3, aligned right of center
--              4, aligned left of center

-- * Show remaining ProjectLength added to context-menu
-- * Show next/previous marker/projectstart/projectend/region and (remaining) time since/til the marker
-- * Show Projectlength added
-- * Show Time-selection start/end/length added
-- * when Clock has keyboard-focus, set keyboard-context to Arrange View, so keystrokes work
--        improvement compared to earlier version, due new features in Reaper's API
-- * includes now a visible settings-button which shows the same menu, as rightclick, but gives a better clue, THAT there are settings
-- * various bugfixes


dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
isnewvalue, filename, section, cmdid = reaper.get_action_context()

-- hole GUI Library

local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
GUI = dofile(script_path .. "ultraschall_gui_lib.lua")


function setColor (r,g,b)
  gfx.set(r,g,b)
end


local function roundrect(x, y, w, h, r, antialias, fill)

  local aa = antialias or 1
  fill = fill or 0

  if fill == 0 or false then
    gfx.roundrect(x, y, w, h, r, aa)
  elseif h >= 2 * r then

    -- Corners
    gfx.circle(x + r, y + r, r, 1, aa)      -- top-left
    gfx.circle(x + w - r, y + r, r, 1, aa)    -- top-right
    gfx.circle(x + w - r, y + h - r, r , 1, aa)  -- bottom-right
    gfx.circle(x + r, y + h - r, r, 1, aa)    -- bottom-left

    -- Ends
    gfx.rect(x, y + r, r, h - r * 2)
    gfx.rect(x + w - r, y + r, r + 1, h - r * 2)

    -- Body + sides
    gfx.rect(x + r, y, w - r * 2, h + 1)

  else

    r = h / 2 - 1

    -- Ends
    gfx.circle(x + r, y + r, r, 1, aa)
    gfx.circle(x + w - r, y + r, r, 1, aa)

    -- Body
    gfx.rect(x + r, y, w - r * 2, h)

  end

end


function count_all_warnings() -- zähle die Arten von Soundchecks aus
  
  event_count = ultraschall.EventManager_CountRegisteredEvents()
  EventIdentifier=ultraschall.EventManager_GetAllEventIdentifier()
  --event_count=1
  local active_warning_count = 0
  local paused_warning_count = 0
  local passed_warning_count = 0

  --print_update("")
  for i = 1, event_count do

-- old code,can be removed, if soundcheck works fine...
--    local EventIdentifier = ""
--    EventIdentifier, EventName, CallerScriptIdentifier, CheckAllXSeconds, CheckForXSeconds, StartActionsOnceDuringTrue, EventPaused, CheckFunction, NumberOfActions, Actions = ultraschall.EventManager_EnumerateEvents(i)
--    A=reaper.GetExtState("ultraschall_eventmanager", "EventIdentifier")
--    last_state, last_statechange_precise_time = ultraschall.EventManager_GetLastCheckfunctionState2(EventIdentifier)

-- new code, that shall replace the old code, as this here is much faster
    local EventPaused = ultraschall.EventManager_GetEventPausedState(i)
    
    
    last_state, last_statechange_precise_time = ultraschall.EventManager_GetLastCheckfunctionState2(EventIdentifier[i])

    if last_state == true and EventPaused ~= true then -- es ist eine Warnung und sie steht nicht auf ignored
      active_warning_count = active_warning_count +1
    elseif EventPaused == true then
      paused_warning_count = paused_warning_count + 1
    end

  end
  passed_warning_count = event_count - active_warning_count - paused_warning_count
  --]]
  
  return active_warning_count, paused_warning_count, passed_warning_count
end


function GetProjectLength()
  if reaper.GetPlayState()&4==4 and reaper.GetProjectLength()<reaper.GetPlayPosition() then
    return reaper.GetPlayPosition()
  else
    return reaper.GetProjectLength()
  end
end
-- Retina Management
-- Get DPI
retval, dpi = reaper.ThemeLayout_GetLayout("tcp", -3)

if dpi=="512" then
  gfx.ext_retina=1
  retina_mod = 1
else
  gfx.ext_retina=0
  retina_mod = 0.5
end


-- Choose the right graphics and scaling and position of the settings-button
if gfx.ext_retina==1 then
  zahnradbutton_unclicked=gfx.loadimg(1000, reaper.GetResourcePath().."/Scripts/Ultraschall_Gfx/Ultraclock/Settings_Retina.png") -- the zahnradbutton itself
  zahnradbutton_clicked=gfx.loadimg(1001, reaper.GetResourcePath().."/Scripts/Ultraschall_Gfx/Ultraclock/Settings_active_Retina.png") -- the zahnradbutton itself
else
  zahnradbutton_unclicked=gfx.loadimg(1000, reaper.GetResourcePath().."/Scripts/Ultraschall_Gfx/Ultraclock/Settings.png") -- the zahnradbutton itself
  zahnradbutton_clicked=gfx.loadimg(1001, reaper.GetResourcePath().."/Scripts/Ultraschall_Gfx/Ultraclock/Settings_active.png") -- the zahnradbutton itself
end

zahnradbutton_x, zahnradbutton_y=gfx.getimgdim(1000) -- get the dimensions of the zahnradbutton
zahnradscale=.7       -- drawing-scale of the zahnradbutton
zahnradbutton_posx=10 -- x-position of the zahnradbutton
zahnradbutton_posy=1  -- y-position of the zahnradbutton


function copy(obj, seen)
  --copy an array
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
  return res
end

function Init()
  -- Initializes the UltraClock

  width,height=400,400 -- size of the window
  refresh= 0.5 --in seconds

  --STD Settings
  -- The settings for the 5 lines of displayed messages
  -- add one to the for-loop and a
  --   txt_line[idx]={ ... } - line to add another line of text
  -- the parameters are: y = the relative y-position of the line.
  --                     size = the relative font-size
  -- these parameters will be fitted to the current size of the UltraClock automatically
  --
  -- Important: y-position>1 might be displayed outside of the window!
  txt_line={}
  for i=1,7 do txt_line[i]={} end -- create 2d array for 4 lines of text
  txt_line[2]={y=0.05, size=0.25}    -- current date
  txt_line[1]={y=0.05 , size=0.25}   -- current time
  txt_line[3]={y=0.11, size=0.16}  -- current playstate
  txt_line[4]={y=0.17, size=0.9}  -- current position

  txt_line[7]={y=0.485, size=0.16}     -- time-selection-text
  txt_line[8]={y=0.55, size=0.25}  -- time-selection

  txt_line[9]={y=0.69, size=0.16}  -- project-length-text
  txt_line[10]={y=0.5, size=0.16} -- project-length

  txt_line[5]={y=0.79, size=0.16}  -- markernames
  txt_line[6]={y=0.86, size=0.25}   -- marker positions

  if reaper.GetOS()=="Win64" or reaper.GetOS()=="Win32" then
    txt_line[11]={y=0.99, size=22 * retina_mod}   -- Soundcheck
  else
    txt_line[11]={y=0.99, size=21 * retina_mod}   -- Soundcheck
  end

  txt_line_preset={} for i=1,7 do txt_line_preset[i]=copy(txt_line) end --copy STD Setting to all presets

  --edit needed settings in presets
  -- RTC - RealTimeClock
  -- TC - TimeCode
  -- date - the current date
  txt_line_preset[1][1].y=-100000 --only RTC, center

  txt_line_preset[2][3].y=0.3  --Status and TC only
  txt_line_preset[2][4].y=0.41

  txt_line_preset[4][2].y=-100000 --date only
  txt_line_preset[4][2].size=0.8

  txt_line_preset[5][1].y=-100000 --date + RTC
  txt_line_preset[5][2].y=0.26 --date only

  txt_line_preset[6][2].y=0.2 --date and TC
  txt_line_preset[6][3].y=0.45
  txt_line_preset[6][4].y=0.56
  txt_line_preset[6][2].size=0.8

  --set font depending on os

  operationSystem = reaper.GetOS()

  if string.match(operationSystem, "OS") then -- es ist ein Mac System
    clockfont="Helvetica" clockfont_bold="Helvetica"
    font_divisor=3.2 --window height / font_divisor = fontsize
  elseif reaper.GetOS()=="Win64" or reaper.GetOS()=="Win32" then
    clockfont="Arial" clockfont_bold="Arial"
    font_divisor=2.8 --window height / font_divisor = fontsize
  else clockfont="Arial" clockfont_bold="Arial"
    font_divisor=3.2
  end

  -- get the last docked-state and selected preset from the ultraschall.ini
  preset = ultraschall.GetUSExternalState("ultraschall_clock", "preset")
  docked = ultraschall.GetUSExternalState("ultraschall_clock", "docked")

  if type(preset)~="string" or preset==nil then preset=3 else preset=tonumber(preset) end
  if docked=="false" then docked=false else docked=true end


  --INIT Menu Items
  uc_menu={} for i=1,10 do uc_menu[i]={} end --create 2d array for 6 menu entries

  uc_menu[1]={text="Show LUFS (Master)"    , checked= (preset&1==1)}
  uc_menu[2]={text="Show Realtime", checked= (preset&2==2)}
  uc_menu[3]={text="Show Timecode", checked= (preset&4==4)}

  uc_menu[4]={text="Show Remaining Project Time"    , checked= (preset&8==8)}
  uc_menu[5]={text="Show Time-Selection"    , checked= (preset&16==16)}
  uc_menu[6]={text="Show Project Length"    , checked= (preset&32==32)}
  uc_menu[7]={text="Show Remaining Time until next Marker/Region/Projectend", checked= (preset&64==64)}

  uc_menu[8]={text="", checked=false} -- separator
  uc_menu[9]={text="Dock Dashboard window to Docker", checked=docked}
  uc_menu[10]={text="Close Window",checked=false}
end

function InitGFX()
  gfx.clear=0x333333 --background color
  reaper.SetToggleCommandState(section, cmdid, 1)
  gfx.init("Dashboard",width,height,false) --create window
  if docked then d=1 else d=0 end

-- Ralf: Das könnte das Problem sein, dass er versucht in Dock4 zu docken.
--       Stattdessen dockt er
--          im Setup-View in den rechten Docker, wo die ProjectBay im Storyboard Modus ist.
--          im Edit-View im TopDocker über der Maintoolbar
--          im Storyboardmodus im gleichen Docker, wie die ProjectBay
--       Der ist vielleicht im Screenset nicht vorgesehen?

  if ultraschall.GetUSExternalState("ultraschall_gui", "view") == "record" then
    dock_id = 4
  else
    dock_id = 5
  end

  gfx.dock( d + 256 * dock_id) -- dock it do docker 4 (&1=docked)
  gfx.update()
  reaper.SetCursorContext(1) -- Set Cursor context to the arrange window, so keystrokes work
end

function showmenu(trigger)
  local menu_string=""
  local i=1
  for i=1,#uc_menu do
    if uc_menu[i].checked==true then menu_string=menu_string.."!" end
    menu_string=menu_string..uc_menu[i].text.."|"
  end
  if trigger==nil then gfx.x, gfx.y= gfx.mouse_x, gfx.mouse_y else gfx.x=zahnradbutton_posx+10 gfx.y=zahnradbutton_posx+10 end
  local ret=gfx.showmenu(menu_string)
  local ret2=ret

  if ret>0 then -- a line was clicked
    if ret>7 then ret2=ret+1 end -- separator does not have an id ...
    if uc_menu[ret2].checked~=nil then
      uc_menu[ret2].checked=not uc_menu[ret2].checked
      preset=0
      for i=1,7 do
        if uc_menu[i].checked then preset=preset+2^(i-1) -- build preset from menu
        end
      end
    end
  end

  return ret
end

function WriteAlignedText(text, color, font, size, y, offset, fixed) -- if y<0 then center horizontally
  -- text - the text to display
  -- color - the color in which to display
  -- font - the font-style in which to display
  -- size - the size of the font
  -- y - the y-position of the text

  -- offset - nil or 0, center text
  --          1, aligned left
  --          2, aligned right
  --          3, aligned right of center
  --          4, aligned left of center

  fontsize_fixed = fixed or 0
  if type(offset)~="number" then offset=0 end
  gfx.r=(color & 0xff0000) / 0xffffff
  gfx.g=(color & 0x00ff00) / 0xffff
  gfx.b=(color & 0x0000ff) / 0xff
  gfx.setfont(1, font, size, 98) -- it's all bold, anyway
  local w, h=gfx.measurestr(text)
  if y<0 then y=(gfx.h-h)/2 end -- center if y<0
  if offset==nil or offset==0 then gfx.x=(gfx.w-w)/2+offset
  elseif offset==1 then gfx.x=0
  elseif offset==2 then gfx.x=gfx.w-gfx.measurestr(text)
  elseif offset==3 then gfx.x=gfx.w/2
  elseif offset==4 then gfx.x=(gfx.w/2)-gfx.measurestr(text)
  end
  gfx.y=y
  gfx.drawstr(text)
end

function get_position(integer)
    playstate=reaper.GetPlayState() --0 stop, 1 play, 2 pause, 4 rec possible to combine bits
    if playstate & 1==1 and (integer==nil or integer==0) then return reaper.GetPlayPosition()
    elseif (playstate & 1==1 or playstate &2==2) and integer==1 then return (reaper.GetProjectLength()-reaper.GetPlayPosition())*(-1)
    elseif (playstate==0) and integer==1 then return (reaper.GetProjectLength()-reaper.GetCursorPosition())*(-1)
    elseif (playstate & 1==1 or playstate &2==2) and integer==2 then
      elementposition_prev, elementtype_prev, number_prev, elementposition_next, elementtype_next, number_next= ultraschall.GetClosestGoToPoints("1", reaper.GetPlayPosition(), false, true, true)
      return elementposition_prev-reaper.GetPlayPosition(), elementtype_prev, elementposition_next-reaper.GetPlayPosition(), elementtype_next
    elseif playstate==0 and integer==2 then
      elementposition_prev, elementtype_prev, number_prev, elementposition_next, elementtype_next, number_next= ultraschall.GetClosestGoToPoints("1", reaper.GetCursorPosition(), false, true, true)
      return elementposition_prev-reaper.GetCursorPosition(), elementtype_prev, elementposition_next-reaper.GetCursorPosition(), elementtype_next
    else return reaper.GetCursorPosition() end
end

function formattimestr(pos)
  if pos==nil then return end
  if pos<0 then pos=pos*-1
    pos=reaper.format_timestr_len(pos, "", 0, 5)
    pos="-"..pos
  else
    pos=reaper.format_timestr_len(pos, "", 0, 5)
  end
  return pos:match("(.*)%:")
end

function openWindowLUFS()

  local mastertrack = reaper.GetMasterTrack(0)
  local lufs_count = 0

  for i = 0, reaper.TrackFX_GetCount(mastertrack) do
    retval, fxName = reaper.TrackFX_GetFXName(mastertrack, i, "")
    if string.find(fxName, "LUFS") then
      lufs_count = lufs_count +1
    end
  end

  if lufs_count == 0 then -- es gibt noch keinen LUFS-Effekt auf dem Master, also hinzufügen. 
    added = ultraschall.LUFS_Metering_AddEffect(false)

  end

  ultraschall.LUFS_Metering_ShowEffect() -- zeige den Effek
    
end


function drawClock()
  gfx.x=zahnradbutton_posx
  gfx.y=zahnradbutton_posy
  gfx.blit(zahnradbutton_unclicked, zahnradscale, 0)
  if uc_menu[3].checked then -- get Timecode/Status
    playstate=reaper.GetPlayState()
    if reaper.GetSetRepeat(-1)==1 then repeat_txt=" (REPEAT)" else repeat_txt="" end
    if playstate == 1 then
      if repeat_txt~="" then txt_color=0x15729d else txt_color=0x2092c7 end
      status="PLAYING"..repeat_txt --play
      elseif playstate == 5 then txt_color=0xf24949 status="RECORDING" --record
      elseif playstate == 2 then
        if repeat_txt~="" then txt_color=0xa86010 else txt_color=0xd17814 end
        status="PAUSED"..repeat_txt --play/pause
      elseif playstate == 6 then txt_color=0xff6b4d status="REC/PAUSED" --record/pause
      elseif playstate == 0 then txt_color=0xeeeeee status="STOPPED" --record/pause
      else txt_color=0xb3b3b3 status=""
    end
    --A=uc_menu[5].checked
    if uc_menu[4].checked==true then pos=get_position(1)//1
    else
      pos=get_position()//1
    end

    pos=formattimestr(pos)
  end


  -- calculate fontsize and textpositions depending on aspect ratio of window
  if gfx.w/gfx.h < 4/3 then -- if narrower than 4:3 add empty space on top and bottom
     fsize=gfx.w/4*3/font_divisor
     border=(gfx.h-gfx.w/4*3)/2 + (15 * retina_mod)
     height=gfx.w/4*3 - (65 * retina_mod)
   else
    fsize=gfx.h/font_divisor
    border=40 * retina_mod
    height=gfx.h -(120 * retina_mod)
   end

  preset=0
  for i=1, 8 do
    if uc_menu[i].checked then
      preset=preset+2^(i-1)
    end
  end
  if preset~=oldpreset then
    --AAA=ultraschall.SetUSExternalState("ultraschall_clock", "preset", preset)     --save state preset
  end

  oldpreset=preset

  if preset==0 or preset==8.0 then
    WriteAlignedText("All displays are turned off :-(",0xbbbbbb, clockfont_bold, fsize/4,-1)
  end

  --write text
  -- Date
  if uc_menu[1].checked then

    LUFS_integral, target, dB_Gain, FX_active = ultraschall.LUFS_Metering_GetValues()

    if LUFS_integral > target-1 and LUFS_integral <= target+1 then -- Grün
      date_color = 0x15ee15
    elseif LUFS_integral > target+1 and LUFS_integral <= target+2 then -- Gelb
      date_color = 0xeeee15
    elseif LUFS_integral > target+2 then -- Rot
      date_color = 0xee5599
    else
      date_color = 0x2092c7 -- Blau
    end
  
    -- roundrect(17*retina_mod, txt_line[2].y*height+border-2, 14*retina_mod, 30*retina_mod, 5*retina_mod, 5, 1)
    -- if retina_mod == 0.5 then
    --   roundrect(19*retina_mod, txt_line[2].y*height+border-2, 10*retina_mod, 26*retina_mod, 0, 0, 1)
    -- end

    Date = tostring(LUFS_integral).." LUFS"
    if FX_active == 0 then 
      Date = "? LUFS" 
      date_color = 0x777777
    end
    

  else
    Date=""
  end

  -- RealTime
  if uc_menu[2].checked then
    time=os.date("%H:%M:%S")
  else
    time=""
  end

  if Date~="" then
    date_position_y = txt_line[2].y*height+border
    WriteAlignedText(" "..Date, date_color, clockfont_bold, txt_line[2].size * fsize, date_position_y,1) -- print realtime hh:mm:ss
  end
  if time~="" then
    WriteAlignedText(time.." ",0xb3b3b3, clockfont_bold, txt_line[1].size * fsize,txt_line[1].y*height+border,2) -- print realtime hh:mm:ss
  end


  -- Soundcheck


  soundcheck_y_offset = 70 * retina_mod



  setColor(0.27,0.27,0.27)
  -- gfx.roundrect(50, 50, 100, 50, 10, 1)

  roundrect(10*retina_mod, gfx.h -(soundcheck_y_offset - 6*retina_mod), (gfx.w - 20*retina_mod), 41*retina_mod, 10*retina_mod, 1, 1)

  active_warning_count, paused_warning_count, passed_warning_count = count_all_warnings()

  WriteAlignedText("   Soundcheck",0x777777, clockfont_bold, txt_line[11].size , gfx.h -(soundcheck_y_offset + 24*retina_mod),1) -- print

  -----------
  -- passed
  -----------

  if passed_warning_count > 0 then
    setColor(0.15,0.95,0.15)
  else
    setColor(0.5,0.5,0.5)
  end

    roundrect(17*retina_mod, gfx.h -(soundcheck_y_offset - 12*retina_mod), 14*retina_mod, 30*retina_mod, 5*retina_mod, 5, 1)
    if retina_mod == 0.5 then
      roundrect(19*retina_mod, gfx.h -(soundcheck_y_offset - 14*retina_mod), 10*retina_mod, 26*retina_mod, 0, 0, 1)
    end

    -- print (gfx.w)

    if gfx.w > 480 * retina_mod then
      WriteAlignedText("       PASSED: "..passed_warning_count.."",0xcccccc, clockfont_bold, txt_line[11].size, gfx.h -(soundcheck_y_offset - 18*retina_mod),1,1)
    else
      WriteAlignedText("        "..passed_warning_count.."",0xcccccc, clockfont_bold, txt_line[11].size, gfx.h -(soundcheck_y_offset - 18*retina_mod),1,1)
    end

  ------------------
  -- PAUSED
  ------------------

  if paused_warning_count > 0 then
    setColor(0.95,0.95,0.15)
    sc_txt_color = 0xcccccc
  else
    setColor(0.5,0.5,0.5)
    sc_txt_color = 0x888888
  end

  if gfx.w > 480 * retina_mod then
    roundrect(gfx.w/2-79* retina_mod, gfx.h -(soundcheck_y_offset - 12*retina_mod), 14*retina_mod, 30*retina_mod, 5*retina_mod, 1, 1)

    if retina_mod == 0.5 then
      roundrect(gfx.w/2-79* retina_mod , gfx.h -(soundcheck_y_offset - 14*retina_mod), 10*retina_mod, 26*retina_mod, 0, 1, 1)
    end

    WriteAlignedText("    IGNORED: "..paused_warning_count.."  ",sc_txt_color, clockfont_bold, txt_line[11].size, gfx.h -(soundcheck_y_offset - 18*retina_mod),0)
  else
    roundrect(gfx.w/2-15* retina_mod, gfx.h -(soundcheck_y_offset - 12*retina_mod), 14*retina_mod, 30*retina_mod, 5*retina_mod, 1, 1)
    if retina_mod == 0.5 then
      roundrect(gfx.w/2-16* retina_mod , gfx.h -(soundcheck_y_offset - 14*retina_mod), 10*retina_mod, 26*retina_mod, 0, 0, 1)
    end
    WriteAlignedText("       "..paused_warning_count.."",sc_txt_color, clockfont_bold, txt_line[11].size, gfx.h -(soundcheck_y_offset - 18*retina_mod),0)
  end
  -- if active_warning_count > 0 then

  -------------
  -- WARNING
  -------------


  if active_warning_count > 0 then
    setColor(0.95,0.15,0.15)
    sc_txt_color = 0xcccccc
  else
    setColor(0.5,0.5,0.5)
    sc_txt_color = 0x888888
  end


  if gfx.w > 480 * retina_mod then
    roundrect(gfx.w - 166 * retina_mod , gfx.h -(soundcheck_y_offset - 12*retina_mod), 14*retina_mod, 30*retina_mod, 5*retina_mod, 1, 1)
    if retina_mod == 0.5 then
      roundrect(gfx.w - 164 * retina_mod , gfx.h -(soundcheck_y_offset - 14*retina_mod), 12*retina_mod, 26*retina_mod, 0, 0, 1)
    end
    WriteAlignedText("WARNING: "..active_warning_count.."   ",sc_txt_color, clockfont_bold, txt_line[11].size, gfx.h -(soundcheck_y_offset - 18*retina_mod),2)
  else
    roundrect(gfx.w - 59 * retina_mod , gfx.h -(soundcheck_y_offset - 12*retina_mod), 14*retina_mod, 30*retina_mod, 5*retina_mod, 1, 1)
    if retina_mod == 0.5 then
      roundrect(gfx.w - 57 * retina_mod , gfx.h -(soundcheck_y_offset - 14*retina_mod), 12*retina_mod, 26*retina_mod, 0, 0, 1)
    end
    WriteAlignedText(" "..active_warning_count.."   ",sc_txt_color, clockfont_bold, txt_line[11].size, gfx.h -(soundcheck_y_offset - 18*retina_mod),2)
  end

  -- end --


  -- Projecttime and Play/RecState
  if uc_menu[3].checked then
    if uc_menu[4].checked==true and reaper.GetProjectLength()<get_position() then plus="+" else plus="" end
    checkpos=pos:match("(.-):")
    if checkpos:len()==1 then addzero="0" else addzero="" end
    WriteAlignedText(""..status,txt_color, clockfont_bold, txt_line[3].size * fsize ,txt_line[3].y*height+border) -- print Status (Pause/Play...)
    WriteAlignedText(plus..addzero..pos, txt_color, clockfont_bold, txt_line[4].size * fsize,txt_line[4].y*height+border) --print timecode in h:mm:ss format
  end

  -- Time Selection
  if uc_menu[5].checked then
    start, end_loop = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    length=end_loop-start
    if length > 0 then
      WriteAlignedText("Time Selection",0xffbb00, clockfont_bold, txt_line[7].size * fsize, txt_line[7].y*height+border,0) -- print date
      start=reaper.format_timestr_len(start, "", 0, 5):match("(.*):")
      end_loop=reaper.format_timestr_len(end_loop, "", 0, 5):match("(.*):")
      length=reaper.format_timestr_len(length, "", 0, 5):match("(.*):")
      WriteAlignedText(start.."     [".. length.."]     "..end_loop,0xffbb00, clockfont_bold, txt_line[8].size * fsize, txt_line[8].y*height+border,0) -- print date
    else
      -- WriteAlignedText("Time Selection",0xaaaa00, clockfont_bold, txt_line[7].size * fsize, txt_line[7].y*height+border,0) -- print date
      -- WriteAlignedText("-:--:-- < (".. "0:00:00"..") > -:--:--",0xaaaa44, clockfont_bold, txt_line[8].size * fsize, txt_line[8].y*height+border,0) -- print date
    end
  end

  -- Project Length
  if uc_menu[6].checked then
    WriteAlignedText("Project Duration: "..reaper.format_timestr_len(GetProjectLength(),"", 0,5):match("(.*):"),0xb6b6bb, clockfont_bold, txt_line[9].size * fsize, txt_line[9].y*height+border,0) -- print date
    -- WriteAlignedText(reaper.format_timestr_len(GetProjectLength(),"", 0,5):match("(.*):"),0xb6b6bb, clockfont_bold, txt_line[10].size * fsize, txt_line[10].y*height+border,0) -- print date
  end

  -- Next/Previous Marker/Region
  if uc_menu[7].checked then
    prevtime, prevelm, nexttime, nextelm = get_position(2)

    prevelm=string.gsub(prevelm,"Marker:","M:")
    nextelm=string.gsub(nextelm,"Marker:","M:")
    prevelm=string.gsub(prevelm,"Region_.-:","R:")
    nextelm=string.gsub(nextelm,"Region_.-:","R:")

    WriteAlignedText("  "..prevelm:sub(1,22),0xb6b6bb, clockfont_bold, txt_line[5].size * fsize ,txt_line[5].y*height+border,1) -- print previous marker/region/projectstart/end
    WriteAlignedText(nextelm:sub(1,20).."  ",0xb6b6bb, clockfont_bold, txt_line[5].size * fsize ,txt_line[5].y*height+border,2) -- print next marker/region/projectstart/end

    prevtime=formattimestr(prevtime*(-1))
    nexttime=formattimestr(nexttime*(-1))
    string.gsub(prevelm,"Region_beg:","Reg: ")
    string.gsub(prevelm,"Region_end:","Reg: ")
    WriteAlignedText(" "..prevtime,0xb6b6bb, clockfont_bold, txt_line[6].size * fsize ,txt_line[6].y*height+border,1) -- print date
    WriteAlignedText("[Marker]",0xb6b6bb, clockfont_bold, txt_line[6].size * fsize ,txt_line[6].y*height+border,0) -- print date
    WriteAlignedText(nexttime.." ",0xb6b6bb, clockfont_bold, txt_line[6].size * fsize ,txt_line[6].y*height+border,2) -- print date
  end
  gfx.update()
  lasttime=reaper.time_precise()
  gfx.set(0.4,0.4,0.4,0.8)
  gfx.set(1)
end


function MainLoop()
  if reaper.time_precise() > lasttime+refresh or gfx.w~=lastw or gfx.h~=lasth then drawClock()  end

  if Triggered==true then
    local ret=showmenu(menuposition)
    menuposition=nil

    if ret==8 then -- /undock
      dock_state=gfx.dock(-1)
      if  dock_state & 1 == 1 then gfx.dock(dock_state -1) else gfx.dock(dock_state+1) end
    elseif ret==9 then exit_clock()
    end

    if gfx.dock(-1)&1==1 then is_docked="true" else is_docked="false" end

    AAA2=ultraschall.SetUSExternalState("ultraschall_clock", "docked", is_docked)  --save state docked
    ultraschall.ShowErrorMessagesInReascriptConsole()
  end

  if Triggered==nil then
    if gfx.mouse_cap & 2 == 2 then -- right mousecklick
      Triggered=true
    elseif (gfx.mouse_cap & 1 ==1) and gfx.mouse_x>=zahnradbutton_posx and gfx.mouse_x<=zahnradbutton_posx+(zahnradbutton_x*zahnradscale) and gfx.mouse_y>=zahnradbutton_posy and gfx.mouse_y<zahnradbutton_posy+(zahnradbutton_y*zahnradscale) then --left mouseclick
      Triggered=true
      menuposition=1
      gfx.x=zahnradbutton_posx
      gfx.y=zahnradbutton_posy
      gfx.blit(zahnradbutton_clicked, zahnradscale, 0)

    elseif (gfx.mouse_cap & 1 ==1) and gfx.mouse_y>gfx.h-(80*retina_mod) then -- Linksklick auf Soundcheck-Footer
      id = reaper.NamedCommandLookup("_Ultraschall_Soundcheck_Startgui")
      reaper.Main_OnCommand(id,0)
    
    elseif uc_menu[1].checked then  -- Das LUFS-Meter ist aktiviert
      if (gfx.mouse_cap & 1 ==1) and gfx.mouse_y < date_position_y+30 * retina_mod and gfx.mouse_y > date_position_y-10*retina_mod and gfx.mouse_x<(120*retina_mod) then -- Linksklick auf LUFS-Bereich
        openWindowLUFS()
      end
    end
  else
    Triggered=nil
  end

--  view = ultraschall.GetUSExternalState("ultraschall_gui", "view") -- get the actual view

  --loop if GUI is NOT closed and VIEW is Recording
  KeyVegas=gfx.getchar()
  if KeyVegas~=-1 then
    lastw, lasth=gfx.w, gfx.h
    clock_focus_state=gfx.getchar(65536)&2
    if clock_focus_state~=0 then
      reaper.SetCursorContext(1) -- Set Cursor context to the arrange window, so keystrokes work
    end
    gfx.update()
    --ALABAMASONG=GetProjectLength()
    reaper.defer(MainLoop)
  end
end

function exit_clock()
  gfx.quit()
  reaper.SetToggleCommandState(section, cmdid, 0)
end

reaper.atexit(exit_clock)
Init()
InitGFX()
lasttime=reaper.time_precise()-1
reaper.defer(MainLoop)
