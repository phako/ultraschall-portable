--[[
################################################################################
#
# Copyright (c) 2014-2017 Ultraschall (http://ultraschall.fm)
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


dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")

function Msg(val)
	reaper.ShowConsoleMsg(tostring(val).."\n")
end

function runcommand(cmd)     -- run a command by its name

	start_id = reaper.NamedCommandLookup(cmd)
	reaper.Main_OnCommand(start_id,0)

end

function GetPath(str,sep)
    return str:match("(.*"..sep..")")
end

function GetFileName(url)
	return url:match("^.+/(.+)$")
end

function GetFileExtension(url)
  return url:match("^.+(%..+)$")
end



local function splitWords(Lines, limit)
  while #Lines[#Lines] > limit do
          Lines[#Lines+1] = Lines[#Lines]:sub(limit+1)
          Lines[#Lines-1] = Lines[#Lines-1]:sub(1,limit)
  end
end


local function wrap(str, limit)
  local Lines, here, limit, found = {}, 1, limit or 72, str:find("(%s+)()(%S+)()")

  if found then
          Lines[1] = string.sub(str,1,found-1)  -- Put the first word of the string in the first index of the table.
  else Lines[1] = str end

  str:gsub("(%s+)()(%S+)()",
          function(sp, st, word, fi)  -- Function gets called once for every space found.
                  splitWords(Lines, limit)

                  if fi-here > limit then
                          here = st
                          Lines[#Lines+1] = word                                                                                   -- If at the end of a line, start a new table index...
                  else Lines[#Lines] = Lines[#Lines].." "..word end  -- ... otherwise add to the current table index.
          end)

  splitWords(Lines, limit)

  return Lines
end


function buildExportStep()

	local infotable = wrap(StepDescription,60) -- Zeilenumbruch 80 Zeichen für Warnungsbeschreibung



	local light = GUI.Area:new(48,position-5,10,21,3,1,1,state_color)
	table.insert(GUI.elms, light)

	local statusbutton = GUI.Btn:new(65, position-4, 0, 20,         status_txt, "")
	table.insert(GUI.elms, statusbutton)



	local block = GUI.Area:new(210,position-10,752, areaHeight,5,1,1,"section_bg")
	table.insert(GUI.elms, block)

	local heading = GUI.Lbl:new(220, position-2, StepNameDisplay, 0, "txt", 2)
	table.insert(GUI.elms, heading)

	for k, warningtextline in pairs(infotable) do

		local infotext = GUI.Lbl:new(220, warnings_position, warningtextline, 0, "txt_grey")
		table.insert(GUI.elms, infotext)
		warnings_position = warnings_position +20

		-- print(k, v)
	end

	local ButtonPosition = position + (areaHeight*0.5) - 83

	local button_offset = 25
	local button1 = GUI.Btn:new(790, ButtonPosition+40+button_offset, 144, 20,  button_txt, runcommand, button_action)

	if not no_button then
		table.insert(GUI.elms, button1)
	else
		no_button = false
	end


end

function checkImage()

	retval, project_path_name = reaper.EnumProjects(-1, "")
	if project_path_name ~= "" then
		dir = GetPath(project_path_name, separator)
		name = string.sub(project_path_name, string.len(dir) + 1)
		name = string.sub(name, 1, -5)
		name = name:gsub(dir, "")
	end

	-- lookup existing episode image

	img_index = false
	found = false

	if dir then
		endings = {".jpg", ".jpeg", ".png"} -- prefer .png
		for key,value in pairs(endings) do
			img_adress = dir .. "cover" .. value          -- does cover.xyz exist?
			img_test = gfx.loadimg(0, img_adress)
			if img_test ~= -1 then
				img_index = img_test
				img_location = img_adress
			end
		end
	end

	endings = {".jpg", ".jpeg", ".png"} -- prefer .png
	for key,value in pairs(endings) do
		img_adress = string.gsub(project_path_name, ".RPP", value)
		img_test = gfx.loadimg(0, img_adress)
		if img_test ~= -1 then
			img_index = img_test
			img_location = img_adress
		end
	end

	if img_index then     -- there is an image
		found = true
		preview_size = 80      -- preview size in Pixel, always square
		w, h = gfx.getimgdim(img_index)
		if w > h then     -- adjust size to the longer border
			img_ratio = preview_size / w
		else
			img_ratio = preview_size / h
		end
	end

	return found, img_location, img_ratio

end


function checkSlot(path)

	-- lookup existing episode image

	img_index = false
	found = false
	image_slot_path = false

	endings = {".jpg", ".jpeg", ".png"} -- prefer .png
	for key,value in pairs(endings) do
		img_test = gfx.loadimg(0, path .. value)
		if img_test ~= -1 then
			img_index = img_test
			image_slot_path = path .. value
		end
	end

	if img_index then     -- there is an image
		found = true
		preview_size = 37      -- preview size in Pixel, always square
		w, h = gfx.getimgdim(img_index)
		if w > h then     -- adjust size to the longer border
			img_ratio = preview_size / w
		else
			img_ratio = preview_size / h
		end
	end

	return found, image_slot_path, img_ratio, img_name

end



function DeleteImages(url)
	os.remove(url..".jpg")
	os.remove(url..".jpeg")
	os.remove(url..".png")
end

function GetDropzone(x,y)

	for i = 1, #dropzone do
		if x > dropzone[i].x and x < dropzone[i].x + 38 and y > dropzone[i].y and y < dropzone[i].y + 38 then
			return i
		end
	end

	return 0
end

function UsePresetCover(preset_path)

	destination_path = dir .. "cover" .. GetFileExtension(preset_path)
	DeleteImages(dir .. "cover")
	retval = ultraschall.MakeCopyOfFile_Binary(preset_path, destination_path)

end



-- initiate values

local info = debug.getinfo(1,'S');
script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
GUI = dofile(script_path .. "ultraschall_gui_lib.lua")
gfx_path = script_path.."/Ultraschall_Gfx/Soundcheck/"
header_path = script_path.."/Ultraschall_Gfx/Headers/"
cover_path = script_path.."/Ultraschall_Gfx/Covers/"


GUI.name = "Ultraschall Export Assistant"
GUI.w, GUI.h = 1000, 700

-- position always in the centre of the screen

l, t, r, b = 0, 0, GUI.w, GUI.h
__, __, screen_w, screen_h = reaper.my_getViewport(l, t, r, b, l, t, r, b, 1)
GUI.x, GUI.y = (screen_w - GUI.w) / 2, (screen_h - GUI.h) / 2

y_offset = -30  -- move all content up/down

-- dropzones

dropzone = {}
dropzone[1] = {}
dropzone[1]["x"] = 870
dropzone[1]["y"] = 391
dropzone[2] = {}
dropzone[2]["x"] = 870
dropzone[2]["y"] = 432
dropzone[3] = {}
dropzone[3]["x"] = 911
dropzone[3]["y"] = 391
dropzone[4] = {}
dropzone[4]["x"] = 911
dropzone[4]["y"] = 432

-- OS BASED SEPARATOR

if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then     separator = "\\" else separator = "/" end

-- Check if project has been saved

function buildGUI()






		---- GUI Elements ----


	-- if reaper.GetOS() == "Win32" or reaper.GetOS() == "Win64" then

	--      if img_index then     -- there is an episode-image

	GUI.elms = {}


	y_offset = 50  -- move all content up/down
	spacing = 10
	no_button = false

	------------------
  ------- Header
	------------------

  header = GUI.Area:new(0,0,1000,90,0,1,1,"header_bg")
  table.insert(GUI.elms, header)

  logo = GUI.Pic:new(          45,  25,   0,  0,    1,   header_path.."export_logo.png")
  table.insert(GUI.elms, logo)

  headertxt = GUI.Pic:new(          115,  36,   0,  0,    0.8,   header_path.."headertxt_export.png")
  table.insert(GUI.elms, headertxt)




	-- Heading

--	label3 = GUI.Lbl:new(30,  70+y_offset,"Follow these simple steps:", 0)
--	table.insert (GUI.elms, label3)

	-- 1. Export MP3


	filecount, files = ultraschall.GetAllFilenamesInPath(dir)

	state_color = "txt_red"
	status_txt = " no MP3 found"

	for i=1, filecount do
		if ( string.sub( files[i], -3 ) ) == "mp3" then
			state_color = "txt_yellow"
			status_txt = " unknown MP3 found"

		end
	end

	areaHeight = 80
	position = 90 + y_offset
	StepNameDisplay = "1. Export MP3"
	StepDescription = "Render your Podcast to a MP3 File. Make use of our prests in the top right corner of the render-dialog."
	warnings_position = position+30
	button_txt = "Export MP3"
	button_action = "_Ultraschall_Render_Check"

	buildExportStep()


	-- 2. Chapter Markers


	areaHeight = 90
	position = 190 + y_offset
	StepNameDisplay = "2. Chapter Markers"
	state_color = "txt_green"
	StepDescription = "You may take a final look at your chapter markers, and add URLs or images to them."
	warnings_position = position+30
	button_txt = "Edit Chapters"
	button_action = "_Ultraschall_Marker_Dashboard"
	status_txt = " OK"

	buildExportStep()


	-- 3. ID3 Metadata

	areaHeight = 70
	position = 300 + y_offset
	StepNameDisplay = "3. ID3 Metadata"
	state_color = "txt_yellow"
	status_txt = " Missing Metadata"
	StepDescription = "Use the ID3 Editor to add metadata to your podcast."
	warnings_position = position+30
	button_txt = "Edit MP3 Metadata"
	button_action = "_Ultraschall_Edit_ID3_Tags"

	buildExportStep()


	-- 4. - Image


	changed, num_dropped_files, dropped_files, drop_mouseposition_x, drop_mouseposition_y = ultraschall.GFX_GetDropFile()
	if num_dropped_files > 0 and changed then
		-- print ("da: "..dropped_files[1])

		dropzone_id = GetDropzone(drop_mouseposition_x/dpi_scale, (drop_mouseposition_y/dpi_scale)-y_offset)
		source_file = dropped_files[1]
		extension = (GetFileExtension(source_file))

		if dropzone_id ~= 0 then

			-- print(dropzone_id)
			destination_file = cover_path .. tostring(dropzone_id) .. extension
			DeleteImages(cover_path .. tostring(dropzone_id))

		else

			destination_file = dir .. "cover" .. extension
			DeleteImages(dir .. "cover")
			--print (drop_mouseposition_x/dpi_scale.."-".. drop_mouseposition_y/dpi_scale)

		end

		retval = ultraschall.MakeCopyOfFile_Binary(source_file, destination_file)

	else
		-- print ("nix"..tostring(changed))
	end

	found, img_adress, img_ratio = checkImage()

	if found then
		status_txt = " Image found"
		state_color = "txt_green"
		no_button = true

	else
		status_txt = " Missing"
		state_color = "txt_red"
		no_button = true
	end



	areaHeight = 100
	position = 390 + y_offset
	StepNameDisplay = "4. Podcast Episode Image"


	StepDescription = "Just drop a square .jpg, .jpeg or .png image to the empty slot on the right. You may populate the smaller slots with covers for different shows and activate them with a click."
	warnings_position = position+30


	buildExportStep()

	if found then
		logo_path = img_adress
	else
		logo_path = header_path.."dropzone_large.png"
		img_ratio = 1
	end

	-- print(logo_path)

	logo = GUI.Pic:new(784,390+y_offset, 80, 80, img_ratio, logo_path, runcommand, "_Ultraschall_Open_Project_Folder")
	table.insert (GUI.elms, logo)

	if found then
		logo_hover_path = header_path.."dropzone_large_hover.png"
		logo2 = GUI.Pic:new(784,390+y_offset, 80, 80, 1, logo_hover_path, runcommand, "_Ultraschall_Open_Project_Folder")
		table.insert (GUI.elms, logo2)
	end

	-- Preset Slots

	logo_path = header_path.."dropzone_small.png"

	for i = 1, #dropzone do

		found, image_slot_path, img_ratio = checkSlot(cover_path .. i)

		if found then

			logo_slot = GUI.Pic:new(dropzone[i].x, dropzone[i].y + y_offset, 37, 37, img_ratio, image_slot_path, UsePresetCover, image_slot_path)
			table.insert (GUI.elms, logo_slot)

		else

			logo_slot = GUI.Pic:new(dropzone[i].x, dropzone[i].y + y_offset, 38, 38, 1, logo_path, runcommand, "_Ultraschall_Open_Project_Folder")
			table.insert (GUI.elms, logo_slot)

		end

	end


	-- 5. Finalize

	areaHeight = 100
	position = 510 + y_offset
	StepNameDisplay = "5. Finalize MP3"
	state_color = "txt_yellow"
	status_txt = " Ready to finalize"
	StepDescription = "Hit the button and select your MP3 to finalize it with metadata, chapters and episode image!"
	warnings_position = position+30
	button_txt = "Finalize MP3!"
	button_action = "_ULTRASCHALL_INSERT_MEDIA_PROPERTIES"

	buildExportStep()



end



-- Open Export Assistant, when it hasn't been opened yet

if reaper.GetExtState("Ultraschall_Windows", GUI.name) == "" then windowcounter=0 -- Check if window was ever opened yet(and external state for it exists already).
																-- If yes, use temporarily 0 as opened windows-counter;will be changed by ultraschall_gui_lib.lua later
else windowcounter=tonumber(reaper.GetExtState("Ultraschall_Windows", GUI.name)) end -- get number of opened windows

if windowcounter<1 then -- you can choose how many GUI.name-windows are allowed to be opened at the same time.
					   -- 1 means 1 window, 2 means 2 windows, 3 means 3 etc

	GUI.func = buildGUI
	GUI.freq = 2     -- How often in seconds to run the function, so we can avoid clogging up the CPU.

	 buildGUI()
	 GUI.Init()
	 GUI.Main()
end

function atexit()
  reaper.SetExtState("Ultraschall_Windows", GUI.name, 0, false)
end

reaper.atexit(atexit)
