--[[
 VLC Safe Watch - Family movie nights, worry-free
 Author: Dineshkumar R (dina.multi@gmail.com)
 Description: Skip or play specific segments to create safe family viewing experiences
 Version: 2.5.11 - Fixed reopening issues and improved dialog management
 
 Installation:
 1. Save this file as "vlc_safe_watch.lua" (or your preferred name)
 2. Copy to VLC extensions folder:
    - Windows: %APPDATA%\vlc\lua\extensions\
    - macOS: ~/Library/Application Support/VLC/lua/extensions/
    - Linux: ~/.local/share/vlc/lua\extensions\
 3. Restart VLC
 4. Go to View > VLC Safe Watch
--]]

function descriptor()
    return {
        title = "VLC Safe Watch",
        version = "2.5.11", -- Updated version
        author = "Dineshkumar R",
        url = "",
        shortdesc = "VLC Safe Watch",
        description = "Skip or play specific segments to create safe family viewing experiences",
        capabilities = {"menu"}
    }
end

-- ========================================
-- GLOBAL VARIABLES
-- ========================================

local dlg = nil
local segments = {}
local mode = "skip"  -- "play" or "skip"
local editing_index = nil
local instance_counter = 0 
local monitor_timer_id = nil 
local is_activated = false

-- Video state
local video_detected = false
local video_position = 0
local video_length = 0
local video_title = "No video"
local video_path = ""
local video_uri = ""  

-- Step completion status
local step_status = {}

-- UI elements
local ui = {}

-- Indicator styles
local style_incomplete = "<font color=\"red\">●</font>"
local style_complete = "<font color=\"green\">●</font>"

-- ========================================
-- INITIAL STATE FUNCTION
-- ========================================
function reset_all_state()
    vlc.msg.info("VLC Safe Watch: Resetting all global state variables.")
    segments = {}
    mode = "skip"
    editing_index = nil
    
    video_detected = false
    video_position = 0
    video_length = 0
    video_title = "No video"
    video_path = ""
    video_uri = ""

    step_status = {
        step1_complete = false,
        step2_complete = false,
        step3_complete = false,
        step4_complete = false
    }
    ui = {} 
end

-- ========================================
-- MAIN EXTENSION FUNCTIONS
-- ========================================

function activate()
    vlc.msg.info("VLC Safe Watch: ---- ACTIVATE START ----")
    
    -- Prevent multiple activations
    if is_activated then
        vlc.msg.warn("VLC Safe Watch: Already activated, ignoring duplicate activation.")
        if dlg then
            dlg:show()
        end
        return
    end
    
    -- Force cleanup any existing dialog
    if dlg then 
        vlc.msg.warn("VLC Safe Watch: Activate called but dlg was not nil. Forcing cleanup.")
        force_cleanup()
        vlc.misc.mwait(100) -- Longer pause after forced cleanup
    end

    reset_all_state() 
    ui = {} 
    is_activated = true

    vlc.msg.info("VLC Safe Watch: Creating interface...")
    create_interface() 
    
    if dlg then 
        vlc.msg.info("VLC Safe Watch: Interface created. Starting monitor...")
        start_monitoring() 
        
        log("🛡️ VLC Safe Watch activated") 
        
        update_mode() 
        update_segments_display()
        update_step_indicators() 
        update_status("Plugin activated, waiting for video", {
            "Play a video in VLC",
            "Click 'Check' to detect it",
            "Follow steps to create playlist"
        })
        
        vlc.msg.info("VLC Safe Watch: Waiting before show...")
        vlc.misc.mwait(100) 
        vlc.msg.info("VLC Safe Watch: Showing dialog...")
        dlg:show() 
        vlc.msg.info("VLC Safe Watch: Dialog show called.")
    else
        vlc.msg.error("VLC Safe Watch: Failed to create dialog in create_interface.")
        is_activated = false
    end
    vlc.msg.info("VLC Safe Watch: ---- ACTIVATE END ----")
end

function deactivate()
    vlc.msg.info("VLC Safe Watch: ---- DEACTIVATE START ----")
    is_activated = false
    stop_monitoring() 
    force_cleanup()
    reset_all_state() 
    vlc.msg.info("VLC Safe Watch: ---- DEACTIVATE END ----")
end

function force_cleanup()
    vlc.msg.info("VLC Safe Watch: Force cleanup started")
    if dlg then
        vlc.msg.info("VLC Safe Watch: Cleaning up dialog")
        -- Try multiple cleanup methods
        pcall(function() 
            if dlg.clear then dlg:clear() end
        end)
        pcall(function() 
            if dlg.hide then dlg:hide() end
        end)
        pcall(function() 
            if dlg.delete then dlg:delete() end
        end)
        dlg = nil
    end
    vlc.msg.info("VLC Safe Watch: Force cleanup completed")
end

function close() 
    vlc.msg.info("VLC Safe Watch: Close function called (dialog 'X' likely clicked).")
    deactivate()
end

function menu()
    vlc.msg.info("VLC Safe Watch: Menu item clicked.")
    
    -- If already activated, just show the dialog
    if is_activated and dlg then
        vlc.msg.info("VLC Safe Watch: Extension already active, showing dialog.")
        dlg:show()
        return
    end
    
    -- Otherwise, do a full restart
    vlc.msg.info("VLC Safe Watch: Forcing full deactivate and then activate cycle.")
    deactivate() 
    vlc.misc.mwait(150) -- Increased pause
    activate()
end

-- ========================================
-- VIDEO DETECTION & MONITORING
-- ========================================

function start_monitoring()
    stop_monitoring() 
    vlc.msg.info("VLC Safe Watch: Starting monitor timer.")
    monitor_timer_id = vlc.add_timeout(500000, monitor_video) -- 500ms
end

function stop_monitoring()
    if monitor_timer_id then
        vlc.msg.info("VLC Safe Watch: Stopping monitor timer ID: " .. tostring(monitor_timer_id))
        pcall(function() vlc.del_timeout(monitor_timer_id) end) -- Wrap in pcall for safety
        monitor_timer_id = nil
    else
        vlc.msg.info("VLC Safe Watch: stop_monitoring called, but no timer ID found.")
    end
end

function monitor_video()
    -- Check if we're still activated and have a dialog
    if not is_activated or not dlg then 
        vlc.msg.info("VLC Safe Watch: monitor_video found extension deactivated or dlg nil, stopping timer.")
        monitor_timer_id = nil
        return
    end
    
    detect_video()
    update_display()
    
    -- Schedule the next run only if still activated
    if is_activated and dlg then 
        monitor_timer_id = vlc.add_timeout(500000, monitor_video)
    else
        vlc.msg.info("VLC Safe Watch: monitor_video found dlg became nil during execution, stopping timer.")
        monitor_timer_id = nil
    end
end

function detect_video()
    local previous_detection = video_detected
    video_detected = false 
    video_position = 0
    video_length = 0
    video_title = "No video" 
    
    local input = vlc.object.input()
    if not input then
        if previous_detection then
            step_status.step1_complete = false
            if ui and ui.step1_indicator then update_step_indicators() end
        end
        return false
    end
    
    local item = vlc.input.item()
    if not item then
        if previous_detection then
            step_status.step1_complete = false
            if ui and ui.step1_indicator then update_step_indicators() end
        end
        return false
    end
    
    video_uri = item:uri() or "" 
    if video_uri == "" then
        if previous_detection then
            step_status.step1_complete = false
            if ui and ui.step1_indicator then update_step_indicators() end
        end
        return false
    end
    
    video_title = item:name() or "Current Video" 
    local dot_pos = video_title:find("%.[^%.]*$")
    if dot_pos then
        video_title = string.sub(video_title, 1, dot_pos - 1)
    end
    
    video_path = uri_to_display_path(video_uri) 
    
    local time_us = vlc.var.get(input, "time")
    local length_us = vlc.var.get(input, "length")
    local position_float = vlc.var.get(input, "position")
    
    if time_us and length_us and length_us > 0 then
        video_detected = true
        video_position = time_us / 1000000
        video_length = length_us / 1000000
    elseif position_float and position_float > 0 then
        local duration = item:duration()
        if duration and duration > 0 then
            video_detected = true
            video_length = duration
            video_position = position_float * duration
        else
            video_detected = true
            video_length = 7200
            video_position = position_float * video_length
        end
    else
        local playlist = vlc.playlist
        if playlist then
            local status = playlist.status()
            if status == "playing" or status == "paused" then
                video_detected = true
                video_length = 7200
                video_position = 0
            end
        end
    end
    
    if video_detected and not previous_detection then
        step_status.step1_complete = true
        step_status.step2_complete = true 
        if ui and ui.step1_indicator then update_step_indicators() end
        log("✅ Video detected!")
    elseif not video_detected and previous_detection then
        step_status.step1_complete = false
        step_status.step2_complete = false
        if ui and ui.step1_indicator then update_step_indicators() end
        log("❌ Video lost or changed.")
    end
    
    return video_detected
end

-- ========================================
-- FILE PATH HANDLING
-- ========================================

function uri_to_display_path(uri)
    if not uri or uri == "" then return "" end
    local path = uri
    if path:match("^file://") then path = path:gsub("^file:///?", "") end
    path = path:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    if path:match("^/[A-Za-z]:") then path = path:sub(2) end
    path = path:gsub("/", "\\")
    return path
end

function get_safe_video_reference()
    return video_uri
end

-- ========================================
-- USER INTERFACE (Enhanced)
-- ========================================

function create_interface()
    instance_counter = instance_counter + 1
    local current_title = "VLC Safe Watch #" .. instance_counter
    vlc.msg.info("VLC Safe Watch: Creating dialog with title: " .. current_title)
    
    -- Create new dialog
    dlg = vlc.dialog(current_title) 
    
    if not dlg then
        vlc.msg.error("VLC Safe Watch: vlc.dialog() returned nil. Cannot create interface.")
        return 
    end
    
    local row = 1
    
    dlg:add_label("<b><font size='4' color='#1B5E20'>🛡️ VLC Safe Watch</font></b>", 1, row, 4, 1)
    dlg:add_label("<b><font size='2' color='#1976D2'>- Dineshkumar R</font></b>", 3, row, 4, 1)
    row = row + 1
    
    ui.step1_indicator = dlg:add_label(style_incomplete, 1, row, 1, 1)
    dlg:add_label("<b><font color='#1976D2'>1: Detect Video</font></b>", 2, row, 2, 1)
    dlg:add_button("🔄 Check", force_video_detection, 4, row, 1, 1)
    row = row + 1
    
    ui.video_status = dlg:add_label("<font color='#FF6F00'>🔍 Waiting...</font>", 1, row, 2, 1)
    ui.time_display = dlg:add_label("<font color='#424242'>⏱️ --:--:-- / --:--:--</font>", 3, row, 2, 1)
    row = row + 1
    
    ui.step2_indicator = dlg:add_label(style_incomplete, 1, row, 1, 1)
    dlg:add_label("<b><font color='#1976D2'>2: Mode</font></b>", 2, row, 1, 1)
    ui.mode_dropdown = dlg:add_dropdown(3, row, 2, 1)
    ui.mode_dropdown:add_value("⏭️ SKIP marked", "skip")
    ui.mode_dropdown:add_value("▶️ PLAY marked", "play")
    row = row + 1
    
    ui.step3_indicator = dlg:add_label(style_incomplete, 1, row, 1, 1)
    dlg:add_label("<b><font color='#1976D2'>3: Mark Content</font></b>", 2, row, 3, 1)
    row = row + 1
    
    dlg:add_label("Start:", 1, row, 1, 1)
    ui.start_input = dlg:add_text_input("00:00:00", 2, row, 1, 1)
    dlg:add_button("📍 Now", set_start_time, 3, row, 1, 1)
    dlg:add_button("➕ Add", add_segment, 4, row, 1, 1)
    row = row + 1
    
    dlg:add_label("End:", 1, row, 1, 1)
    ui.end_input = dlg:add_text_input("00:00:00", 2, row, 1, 1)
    dlg:add_button("📍 Now", set_end_time, 3, row, 1, 1)
    row = row + 1
    
    dlg:add_label("<b>Marked:</b>", 1, row, 1, 1)
    dlg:add_button("🗑️Del", delete_segment, 2, row, 1, 1)
    dlg:add_button("🧹Clear", clear_segments, 3, row, 1, 1)
    row = row + 1
    
    ui.segments_list = dlg:add_list(1, row, 4, 2) 
    row = row + 2 
    
    ui.step4_indicator = dlg:add_label(style_incomplete, 1, row, 1, 1)
    dlg:add_label("<b><font color='#1976D2'>4: Create Playlist</font></b>", 2, row, 2, 1)
    dlg:add_button("🎬 Create", export_playlist, 4, row, 1, 1)
    row = row + 1
    
    ui.success_section = dlg:add_label("", 1, row, 4, 1)
    row = row + 1
    ui.success_details = dlg:add_label("", 1, row, 4, 1)
    row = row + 1
    
    dlg:add_label("<b>Status:</b>", 1, row, 1, 1)
    ui.status_label = dlg:add_label("Ready!", 2, row, 3, 1)
    row = row + 1
    
    dlg:add_label("<b>Next:</b>", 1, row, 1, 1)
    ui.next_steps_combined = dlg:add_label("Follow prompts.", 2, row, 3, 1)
    row = row + 1

    dlg:add_label("<b>Log:</b>", 1, row, 1, 1)
    ui.feedback = dlg:add_text_input("Plugin loaded. Developed by Dineshkumar R", 2, row, 3, 1)
    row = row + 1
    vlc.msg.info("VLC Safe Watch: UI elements added.")
end

-- ========================================
-- STEP INDICATOR FUNCTIONS
-- ========================================

function update_step_indicators()
    if not dlg or not ui.step1_indicator then 
        vlc.msg.warn("VLC Safe Watch: update_step_indicators called but UI elements not ready.")
        return 
    end 
    vlc.msg.info("VLC Safe Watch: Updating step indicators. S1:"..tostring(step_status.step1_complete).." S2:"..tostring(step_status.step2_complete).." S3:"..tostring(step_status.step3_complete).." S4:"..tostring(step_status.step4_complete))
    
    if ui.step1_indicator then ui.step1_indicator:set_text(step_status.step1_complete and style_complete or style_incomplete) end
    if ui.step2_indicator then ui.step2_indicator:set_text(step_status.step2_complete and style_complete or style_incomplete) end
    if ui.step3_indicator then ui.step3_indicator:set_text(step_status.step3_complete and style_complete or style_incomplete) end
    if ui.step4_indicator then ui.step4_indicator:set_text(step_status.step4_complete and style_complete or style_incomplete) end
end

function check_step3_completion()
    local previously_complete = step_status.step3_complete
    step_status.step3_complete = (#segments > 0)

    if step_status.step3_complete and not previously_complete then
        log("✅ Content marked (Step 3 complete)")
    elseif not step_status.step3_complete and previously_complete then
        log("ℹ️ Content list empty (Step 3 incomplete)")
        step_status.step4_complete = false 
    end

    if dlg then
        update_step_indicators()
    end
end

-- ========================================
-- STATUS UPDATE FUNCTION
-- ========================================

function update_status(current_status, next_steps)
    if not dlg or not ui.status_label then return end
    ui.status_label:set_text(current_status) 
    
    if ui.next_steps_combined then
        if next_steps and #next_steps > 0 then
            local relevant_step = "Follow prompts above." 
            for _, step_text in ipairs(next_steps) do
                if step_text and step_text ~= "..." and 
                   not step_text:lower():find("step %d") and 
                   not step_text:lower():find("playlist will be saved") and
                   not step_text:lower():find("proceed to step") and
                   not step_text:lower():find("mission accomplished") then
                    relevant_step = step_text
                    break 
                end
            end
            if relevant_step == "Follow prompts above." and next_steps[1] then
                relevant_step = next_steps[1]
            end
            ui.next_steps_combined:set_text(relevant_step)
        else
            ui.next_steps_combined:set_text("Follow prompts above.")
        end
    end
end

function show_success_message(filename, folder_info)
    if not dlg or not ui.success_section then return end
    ui.success_section:set_text("<b><font size='3' color='#1B5E20'>🎉 Playlist Created!</font></b>")
    local details_text = string.format(
        "<font color='#1976D2'><b>File:</b> %s (%s)</font>",
        filename, folder_info
    )
    ui.success_details:set_text(details_text)
    update_status("Playlist created: " .. filename, {
        "Close plugin & open file: " .. filename,
        "Enjoy safe viewing!"
    })
end

function hide_success_message()
    if not dlg or not ui.success_section then return end
    ui.success_section:set_text("")
    ui.success_details:set_text("")
end

-- ========================================
-- BUTTON FUNCTIONS
-- ========================================

function force_video_detection()
    if not dlg then return end
    log("🔄 Refreshing video detection...")
    detect_video()
    update_display()
end

function set_start_time()
    if not dlg then return end
    if not video_detected then
        log("❌ Play a video first!")
        update_status("No video detected", {"Play a video", "Click 'Check'", "Then set times"})
        return
    end
    
    detect_video() 
    local time_str = seconds_to_time(video_position)
    ui.start_input:set_text(time_str)
    log("✅ Start time captured: " .. time_str)
    
    if ui.end_input:get_text() ~= "00:00:00" then
        update_status("Start & End times set", {"Click 'Add' to mark content", "Or adjust times"})
    else
        update_status("Start time set (" .. time_str .. ")", {"Set End time", "Then click 'Add'"})
    end
end

function set_end_time()
    if not dlg then return end
    if not video_detected then
        log("❌ Play a video first!")
        update_status("No video detected", {"Play a video", "Click 'Check'", "Then set times"})
        return
    end
    
    detect_video() 
    local time_str = seconds_to_time(video_position)
    ui.end_input:set_text(time_str)
    log("✅ End time captured: " .. time_str)

    if ui.start_input:get_text() ~= "00:00:00" then
        update_status("Start & End times set", {"Click 'Add' to mark content", "Or adjust times"})
    else
        update_status("End time set (" .. time_str .. ")", {"Set Start time", "Then click 'Add'"})
    end
end

function add_segment()
    if not dlg then return end
    local start_text = ui.start_input:get_text()
    local end_text = ui.end_input:get_text()
    
    if not start_text or start_text == "" then 
        log("❌ Set Start time first! Field is empty.")
        update_status("Missing start time", {"Set Start time using 'Now'", "Then set End time & Add"})
        return
    end
    
    if not end_text or end_text == "" or end_text == "00:00:00" then
        log("❌ Set End time! Field is empty or 00:00:00.")
        update_status("Missing or invalid end time", {"Set End time using 'Now'", "Then click 'Add'"})
        return
    end
    
    local start_seconds = time_to_seconds(start_text)
    local end_seconds = time_to_seconds(end_text)
    
    if start_seconds == nil then 
        log("❌ Invalid Start time format! Use HH:MM:SS")
        update_status("Invalid Start time format", {"Use HH:MM:SS or 'Now' buttons", "Then click 'Add'"})
        return
    end

    if end_seconds == nil then 
        log("❌ Invalid End time format! Use HH:MM:SS")
        update_status("Invalid End time format", {"Use HH:MM:SS or 'Now' buttons", "Then click 'Add'"})
        return
    end
    
    if end_seconds <= start_seconds then
        log("❌ End time must be after start time!")
        update_status("End time after start time", {"Fix time values", "Then click 'Add'"})
        return
    end
    
    local duration = end_seconds - start_seconds
    
    if editing_index and editing_index >= 1 and editing_index <= #segments then
        segments[editing_index] = {start = start_seconds, end_time = end_seconds, start_text = start_text, end_text = end_text, duration = duration}
        log("✅ Updated: " .. start_text .. " → " .. end_text)
        update_status("Content updated", {"Mark more or Create playlist"})
        editing_index = nil
    else
        table.insert(segments, {start = start_seconds, end_time = end_seconds, start_text = start_text, end_text = end_text, duration = duration})
        log("✅ Added: " .. start_text .. " → " .. end_text)
        update_status("Content marked", {"Mark more or Create playlist"})
    end
    
    table.sort(segments, function(a, b) return a.start < b.start end)
    update_segments_display()
    check_step3_completion()
    
    ui.start_input:set_text("00:00:00")
    ui.end_input:set_text("00:00:00")
    hide_success_message()
end

function delete_segment()
    if not dlg then return end
    log("🗑️ Delete button clicked")
    if not editing_index or editing_index < 1 or editing_index > #segments then
        log("❌ Select content from list first!")
        update_status("No content selected", {"Click item in list to select", "Then click 'Delete'"})
        return
    end
    
    local deleted = segments[editing_index]
    table.remove(segments, editing_index)
    update_segments_display()
    log(string.format("✅ Deleted: %s → %s", deleted.start_text, deleted.end_text))
    
    ui.start_input:set_text("00:00:00")
    ui.end_input:set_text("00:00:00")
    editing_index = nil
    check_step3_completion()
    
    if #segments > 0 then
        update_status("Content deleted", {"Mark more or Create playlist"})
    else
        update_status("All content deleted", {"Mark content using Step 3"})
    end
    hide_success_message()
end

function clear_segments()
    if not dlg then return end
    log("🧹 Clear button clicked")
    segments = {}
    update_segments_display()
    editing_index = nil
    log("✅ All content cleared")
    check_step3_completion()
    update_status("All content cleared", {"Mark content using Step 3"})
    hide_success_message()
end

function export_playlist()
    if not dlg then return end
    log("🎬 Creating playlist...")
    if #segments == 0 then
        log("❌ No content marked!")
        update_status("No content marked", {"Use Step 3 to mark content", "Then Create playlist"})
        return
    end
    if not video_detected or video_uri == "" then
        log("❌ No video detected!")
        update_status("No video detected", {"Play video & click 'Check'", "Then Create playlist"})
        return
    end
    
    update_status("Creating playlist...", {"Processing content...", "Generating file..."})
    update_mode()
    
    log("✅ Export: Video: " .. video_title .. ", Mode: " .. string.upper(mode) .. ", Segments: " .. #segments)
    
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local safe_title = video_title:gsub("[^%w%-%_ ]", "")
    local m3u_filename = "safe_watch_" .. safe_title .. "_" .. timestamp .. ".m3u"
    
    local content = "#EXTM3U\n# VLC Safe Watch Export\n# Video: " .. video_title .. "\n# URI: " .. video_uri .. "\n# Mode: " .. string.upper(mode) .. "\n# Created: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n# Segments: " .. #segments .. "\n\n"
    
    local playlist_parts = {}
    if mode == "play" then
        log("📝 PLAY mode: playing ONLY marked segments")
        local sorted_segments = {}
        for _, seg in ipairs(segments) do table.insert(sorted_segments, seg) end
        table.sort(sorted_segments, function(a,b) return a.start < b.start end)
        for i, seg in ipairs(sorted_segments) do
            table.insert(playlist_parts, {start = seg.start, end_time = seg.end_time, duration = seg.duration, title = string.format("%s - Play %d (%s-%s)", video_title, i, seg.start_text, seg.end_text)})
        end
    else 
        log("📝 SKIP mode: skipping marked segments")
        local skip_segments = {}
        for _, seg in ipairs(segments) do table.insert(skip_segments, seg) end
        table.sort(skip_segments, function(a,b) return a.start < b.start end)
        
        local current_pos = 0
        for _, skip_seg in ipairs(skip_segments) do
            if current_pos < skip_seg.start then
                table.insert(playlist_parts, {start = current_pos, end_time = skip_seg.start, duration = skip_seg.start - current_pos, title = string.format("%s - Part %d (%s-%s)", video_title, #playlist_parts + 1, seconds_to_time(current_pos), seconds_to_time(skip_seg.start))})
            end
            current_pos = math.max(current_pos, skip_seg.end_time)
        end
        if current_pos < video_length then
            table.insert(playlist_parts, {start = current_pos, end_time = video_length, duration = video_length - current_pos, title = string.format("%s - Part %d (%s-%s)", video_title, #playlist_parts + 1, seconds_to_time(current_pos), seconds_to_time(video_length))})
        end
    end

    local segments_added = 0
    for _, part in ipairs(playlist_parts) do
        local min_duration = (mode == "play") and 0.5 or 0.1 
        if part.duration >= min_duration then
            local start_int = math.floor(part.start)
            local stop_int = math.floor(part.end_time)
            local dur_int = math.floor(part.duration) 
            if dur_int < 1 and part.duration > 0 then dur_int = 1 end 
            if dur_int == 0 and part.duration == 0 then dur_int = 0 end 

            content = content .. string.format("#EXTVLCOPT:start-time=%d\n#EXTVLCOPT:stop-time=%d\n#EXTINF:%d,%s\n%s\n\n", start_int, stop_int, dur_int, part.title, video_uri)
            segments_added = segments_added + 1
        else
             log(string.format("⚠️ Skipped part (too short < %.1fs): %s to %s", min_duration, seconds_to_time(part.start), seconds_to_time(part.end_time)))
        end
    end

    if segments_added == 0 then
        log("❌ No valid segments generated for playlist (all were too short).")
        update_status("No segments long enough", {"Try longer segments", "Or use different mode"})
        return
    end
    
    log(string.format("✅ Generated %d playlist entries.", segments_added))
    
    local saved = false
    local final_path = ""
    local save_locations = get_save_locations(m3u_filename)
    
    for _, loc in ipairs(save_locations) do
        log("💾 Trying: " .. loc.name)
        local file, err = io.open(loc.full_path, "w")
        if file then
            file:write(content)
            file:close()
            saved = true
            final_path = loc.full_path
            log("✅ Saved to: " .. loc.full_path)
            break
        else
            log("❌ Failed save to " .. loc.name .. ": " .. tostring(err))
        end
    end
    
    if saved then
        step_status.step4_complete = true
        if dlg then update_step_indicators() end
        log("🎉 SUCCESS! Playlist created: " .. final_path)
        local filename_only = final_path:match("([^\\]+)$") or m3u_filename
        local folder_info = (get_video_folder() and final_path:find(get_video_folder(), 1, true)) and "Video folder" or final_path:match("(.+)\\") or "Your computer"
        show_success_message(filename_only, folder_info)
    else
        log("❌ Could not save playlist!")
        update_status("Could not save playlist", {"Check VLC Messages (Tools > Messages)", "Copy content & save as .m3u"})
        vlc.msg.info("=== VLC SAFE WATCH EXPORT CONTENT ===\n" .. content .. "\n=== END EXPORT CONTENT ===")
    end
end

function get_save_locations(filename)
    local locations = {}
    local video_folder = get_video_folder()
    if video_folder and video_folder ~= "" then table.insert(locations, {name = "Video folder", full_path = video_folder .. filename}) end
    local userprofile = os.getenv("USERPROFILE")
    if userprofile then
        table.insert(locations, {name = "Desktop", full_path = userprofile .. "\\Desktop\\" .. filename})
        table.insert(locations, {name = "Documents", full_path = userprofile .. "\\Documents\\" .. filename})
    end
    local temp = os.getenv("TEMP") or os.getenv("TMP")
    if temp then table.insert(locations, {name = "Temp folder", full_path = temp .. "\\" .. filename}) end
    table.insert(locations, {name = "Current directory", full_path = ".\\" .. filename})
    return locations
end

function get_video_folder()
    if not video_uri or video_uri == "" then return nil end
    local file_path = video_uri
    if file_path:match("^file://") then file_path = file_path:gsub("^file:///?", "") end
    file_path = file_path:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
    if file_path:match("^/[A-Za-z]:") then file_path = file_path:sub(2) end
    file_path = file_path:gsub("/", "\\")
    local last_slash = file_path:match(".+\\()")
    if last_slash then
        local folder_path = file_path:sub(1, last_slash)
        if test_folder_access(folder_path) then return folder_path end
    end
    return nil
end

function test_folder_access(folder_path)
    if not folder_path or folder_path == "" then return false end
    local test_filename = "vlc_write_test_" .. os.time() .. ".tmp"
    local test_path = folder_path .. test_filename
    local file, err = io.open(test_path, "w")
    if file then
        file:write("test"); file:close()
        pcall(function() os.remove(test_path) end)
        return true
    end
    return false
end

-- ========================================
-- UI UPDATE FUNCTIONS
-- ========================================

function update_display()
    if not dlg then return end 
    if video_detected then
        if ui.video_status then ui.video_status:set_text("<font color='#1B5E20'>✅ " .. video_title .. "</font>") end
        local cur = seconds_to_time(video_position)
        local total = seconds_to_time(video_length)
        local perc = video_length > 0 and (video_position / video_length * 100) or 0
        if ui.time_display then ui.time_display:set_text(string.format("<font color='#1976D2'>⏱️ %s / %s (%.0f%%)</font>", cur, total, perc)) end
        update_step_guidance()
    else
        if ui.video_status then ui.video_status:set_text("<font color='#D32F2F'>❌ No video</font>") end
        if ui.time_display then ui.time_display:set_text("<font color='#424242'>⏱️ Play video in VLC</font>") end
        update_status("No video detected", {"Play a video", "Click 'Check'"})
    end
end

function update_step_guidance()
    if not dlg then return end 
    if not video_detected then
        update_status("No video detected", {"Play a video", "Click 'Check'"})
    elseif #segments == 0 then
        update_status("Video ready, mark content", {"Use 'Now' buttons", "Then click 'Add'"})
    else
        update_status(string.format("%d segments marked", #segments), {"Mark more or Create playlist"})
    end
end

function update_mode()
    if not dlg or not ui.mode_dropdown then return end 
    local selected_value = ui.mode_dropdown:get_value()
    local selected_text = ""
    if ui.mode_dropdown.get_text then 
         selected_text = ui.mode_dropdown:get_text() or ""
    end

    if (type(selected_value) == "string" and selected_value:lower():find("play")) or selected_text:lower():find("play") then
        mode = "play"
    else
        mode = "skip"
    end
    log("🎯 Mode set to: " .. string.upper(mode))
end

function update_segments_display()
    if not dlg or not ui.segments_list then return end 
    ui.segments_list:clear()
    if #segments == 0 then
        ui.segments_list:add_value("📝 No content marked yet", "")
    else
        for i, segment in ipairs(segments) do
            local text = string.format("%d. %s → %s (%s)", i, segment.start_text, segment.end_text, seconds_to_time(segment.duration))
            ui.segments_list:add_value(text, tostring(i))
        end
    end
end

function segments_list_clicked()
    if not dlg or not ui.segments_list then return end 
    local selection = ui.segments_list:get_selection()
    if selection and selection ~= "" then
        editing_index = tonumber(selection)
        if editing_index and editing_index >= 1 and editing_index <= #segments then
            local seg = segments[editing_index]
            if ui.start_input then ui.start_input:set_text(seg.start_text) end
            if ui.end_input then ui.end_input:set_text(seg.end_text) end
            log(string.format("✏️ Editing content %d: %s → %s", editing_index, seg.start_text, seg.end_text))
            update_status("Editing content " .. editing_index, {"Modify times & 'Add' to update", "Or 'Delete Selected'"})
        end
    end
end

function log(message)
    if ui.feedback then 
        ui.feedback:set_text(os.date("[%H:%M:%S] ") .. message)
    end
    vlc.msg.info("VLC Safe Watch: " .. message)
end

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

function time_to_seconds(time_str)
    if not time_str or time_str == "" then return nil end
    local parts = {}
    for part in string.gmatch(time_str, "%d+") do table.insert(parts, tonumber(part)) end
    if #parts == 3 then return parts[1] * 3600 + parts[2] * 60 + parts[3]
    elseif #parts == 2 then return parts[1] * 60 + parts[2]
    elseif #parts == 1 then return parts[1] end
    return nil 
end

function seconds_to_time(seconds)
    if not seconds or seconds < 0 then return "00:00:00" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- ========================================
-- VLC EVENT HANDLERS
-- ========================================

function input_changed()
    if dlg and is_activated then 
        detect_video()
        update_display()
    end
end