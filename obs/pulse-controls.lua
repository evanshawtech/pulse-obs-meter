-- PULSE optional local Browser Source controls. Core tested in Windows OBS 32.2.2.
-- No shell, network, file access, scene changes, source updates, or default keys.
-- See OBS-SETUP.md and ../evidence/HISTORICAL_VALIDATION.md for the tested scope.
-- Focused keys user-confirmed on 2026-10-08; load once through Tools > Scripts.
local obs = obslua
local source_uuid = ""
local status = "Choose a local PULSE Browser Source. No target is selected by default."
local hotkeys = {}
local held = {}
local payloads = {
    increment = '{"schema":1,"action":"increment"}',
    decrement = '{"schema":1,"action":"decrement"}',
    reset = '{"schema":1,"action":"reset"}'
}
local required = {
    "obs_source_get_uuid", "obs_get_source_by_uuid", "obs_source_get_unversioned_id",
    "obs_source_showing", "obs_source_get_settings", "obs_data_get_bool",
    "obs_data_release", "obs_source_release", "obs_source_get_proc_handler",
    "calldata_create", "calldata_set_string", "calldata_destroy", "proc_handler_call"
}

local function compatible()
    for _, name in ipairs(required) do
        if type(obs[name]) ~= "function" then
            status = "Unsupported OBS scripting API: " .. name .. ". No event was sent."
            return false
        end
    end
    return true
end

local function send_command(action)
    if not payloads[action] or not compatible() then return false end
    if source_uuid == "" then
        status = "Choose a local PULSE Browser Source first. No event was sent."
        return false
    end
    local source = obs.obs_get_source_by_uuid(source_uuid)
    if not source then
        status = "Selected source is missing. Re-select its replacement; no event was sent."
        return false
    end
    local settings, data
    -- Release owned source/settings/calldata references on both success and errors.
    local ok, sent = pcall(function()
        if obs.obs_source_get_unversioned_id(source) ~= "browser_source" then
            status = "Selected source is not a Browser Source. No event was sent."
            return false
        end
        settings = obs.obs_source_get_settings(source)
        if not settings or not obs.obs_data_get_bool(settings, "is_local_file") then
            status = "Use Local file with the new PULSE HTML. Remote URLs are not supported."
            return false
        end
        if not obs.obs_source_showing(source) then
            status = "Selected source is not showing. No event was sent or queued."
            return false
        end
        local handler = obs.obs_source_get_proc_handler(source)
        if not handler then
            status = "Browser Source has no procedure handler. No event was sent."
            return false
        end
        data = obs.calldata_create()
        if not data then
            status = "Could not create event data. No event was sent."
            return false
        end
        obs.calldata_set_string(data, "eventName", "pulse-meter-control-v1")
        obs.calldata_set_string(data, "jsonString", payloads[action])
        if not obs.proc_handler_call(handler, "javascript_event", data) then
            status = "Browser event procedure unavailable. No event was sent."
            return false
        end
        status = "Dispatched " .. action .. ". Check the meter visually; delivery is not acknowledged."
        return true
    end)
    if data then obs.calldata_destroy(data) end
    if settings then obs.obs_data_release(settings) end
    obs.obs_source_release(source)
    if not ok then
        status = "OBS API error. Check OBS Script Log. No automatic retry."
        obs.script_log(obs.LOG_WARNING, "PULSE control error: " .. tostring(sent))
        return false
    end
    return sent
end

local function press(action, pressed)
    if not pressed then held[action] = false; return end
    if held[action] then return end
    held[action] = true
    send_command(action)
end
local function on_increment(pressed) press("increment", pressed) end
local function on_decrement(pressed) press("decrement", pressed) end
local function on_reset(pressed) press("reset", pressed) end
local bindings = {
    {"increment", "PULSE: increase selected meter", on_increment},
    {"decrement", "PULSE: decrease selected meter", on_decrement},
    {"reset", "PULSE: reset selected meter", on_reset}
}

local function display_status(props)
    local property = obs.obs_properties_get(props, "status")
    if property then obs.obs_property_set_description(property, status) end
    return true
end
local function test_increment(props) send_command("increment"); return display_status(props) end
local function test_decrement(props) send_command("decrement"); return display_status(props) end
local function test_reset(props) send_command("reset"); return display_status(props) end
local function show_status(props) return display_status(props) end

local function fill_sources(props)
    local list = obs.obs_properties_get(props, "source_uuid")
    obs.obs_property_list_clear(list)
    obs.obs_property_list_add_string(list, "(Choose one local PULSE Browser Source)", "")
    if not compatible() then return display_status(props) end
    local sources = obs.obs_enum_sources()
    local selected_found = source_uuid == ""
    if sources then
        for _, source in ipairs(sources) do
            if obs.obs_source_get_unversioned_id(source) == "browser_source" then
                local uuid = obs.obs_source_get_uuid(source)
                obs.obs_property_list_add_string(list, obs.obs_source_get_name(source), uuid)
                if uuid == source_uuid then selected_found = true end
            end
        end
        obs.source_list_release(sources)
    end
    if not selected_found then
        obs.obs_property_list_add_string(list, "(Selected source missing; choose a replacement)", source_uuid)
    end
    return display_status(props)
end

function script_description()
    return "PULSE optional controls (core tested in Windows OBS 32.2.2; see evidence/REAL-OBS-RESULTS.zh-CN.md; focused keys user-confirmed 2026-10-08; not independently observed). Send +1, -1, or reset only to the selected local Browser Source. Enable OBS Lua controls in a newly exported PULSE HTML first. Close its Interact window and bind PULSE actions in Settings > Hotkeys. Source must be loaded and showing. No default keys or global-shortcut guarantee."
end

function script_properties()
    local props = obs.obs_properties_create()
    obs.obs_properties_add_list(props, "source_uuid", "PULSE Browser Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_properties_add_text(props, "status", status, obs.OBS_TEXT_INFO)
    obs.obs_properties_add_button(props, "refresh", "Refresh source list", fill_sources)
    obs.obs_properties_add_button(props, "test_increment", "Test: +1 selected meter", test_increment)
    obs.obs_properties_add_button(props, "test_decrement", "Test: -1 selected meter", test_decrement)
    obs.obs_properties_add_button(props, "test_reset", "Test: reset selected meter", test_reset)
    obs.obs_properties_add_button(props, "last_status", "Show last dispatch status", show_status)
    fill_sources(props)
    return props
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "source_uuid", "")
end

function script_update(settings)
    local next_uuid = obs.obs_data_get_string(settings, "source_uuid")
    if next_uuid ~= source_uuid then
        source_uuid = next_uuid
        status = "Target changed. Test the selected meter before assigning hotkeys."
    end
end

function script_load(settings)
    script_update(settings)
    for _, binding in ipairs(bindings) do
        local name, label, callback = binding[1], binding[2], binding[3]
        local id = obs.obs_hotkey_register_frontend("pulse_meter." .. name, label, callback)
        hotkeys[name] = id
        local saved = obs.obs_data_get_array(settings, "hotkey_" .. name)
        if saved then
            obs.obs_hotkey_load(id, saved)
            obs.obs_data_array_release(saved)
        end
    end
end

function script_save(settings)
    for _, binding in ipairs(bindings) do
        local name = binding[1]
        if hotkeys[name] then
            local saved = obs.obs_hotkey_save(hotkeys[name])
            if saved then
                obs.obs_data_set_array(settings, "hotkey_" .. name, saved)
                obs.obs_data_array_release(saved)
            end
        end
    end
end

function script_unload()
    for _, binding in ipairs(bindings) do
        if hotkeys[binding[1]] then obs.obs_hotkey_unregister(binding[3]) end
    end
    hotkeys = {}
    held = {}
end
