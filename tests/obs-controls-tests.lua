-- Executes the actual companion with a mock obslua API. Never launches OBS.
-- Run from the project root: lua tests/obs-controls-tests.lua
local groups = 0
local function check(name, fn)
    fn()
    groups = groups + 1
    print("PASS " .. name)
end
local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end

local function boot(target, options)
    options = options or {}
    local env = {events = {}, registered = {}, logs = {}, unregistered = 0, loaded = 0,
        refs = {source = 0, settings = 0, data = 0, arrays = 0, lists = 0}}
    env.sources = {
        a = {uuid = "a", name = "PULSE A", kind = "browser_source", showing = true, settings = {is_local_file = true}},
        b = {uuid = "b", name = "PULSE B", kind = "browser_source", showing = true, settings = {is_local_file = true}},
        remote = {uuid = "remote", name = "Remote browser", kind = "browser_source", showing = true, settings = {is_local_file = false}},
        text = {uuid = "text", name = "Text source", kind = "text_ft2_source", showing = true, settings = {}}
    }
    local obs = {OBS_COMBO_TYPE_LIST = 1, OBS_COMBO_FORMAT_STRING = 1, OBS_TEXT_INFO = 1, LOG_WARNING = 1}
    function obs.obs_get_source_by_uuid(uuid)
        local source = env.sources[uuid]
        if source then env.refs.source = env.refs.source + 1 end
        return source
    end
    function obs.obs_source_get_uuid(source) return source.uuid end
    function obs.obs_source_get_name(source) return source.name end
    function obs.obs_source_get_unversioned_id(source) return source.kind end
    function obs.obs_source_showing(source) return source.showing end
    function obs.obs_source_release() env.refs.source = env.refs.source - 1 end
    function obs.obs_source_get_settings(source) env.refs.settings = env.refs.settings + 1; return source.settings end
    function obs.obs_data_release() env.refs.settings = env.refs.settings - 1 end
    function obs.obs_data_get_bool(settings, key) return settings[key] == true end
    function obs.obs_source_get_proc_handler(source) if options.no_handler then return nil end; return source end
    function obs.calldata_create() env.refs.data = env.refs.data + 1; return {} end
    function obs.calldata_set_string(data, key, value) data[key] = value end
    function obs.calldata_destroy() env.refs.data = env.refs.data - 1 end
    function obs.proc_handler_call(source, name, data)
        equal(name, "javascript_event")
        if options.api_error then error("Simulated procedure failure") end
        if options.no_procedure then return false end
        env.events[#env.events + 1] = {uuid = source.uuid, eventName = data.eventName, jsonString = data.jsonString}
        return true
    end
    function obs.script_log(_, message) env.logs[#env.logs + 1] = message end
    function obs.obs_data_get_string(settings, key) return settings[key] or "" end
    function obs.obs_data_set_default_string(settings, key, value) if settings[key] == nil then settings[key] = value end end
    function obs.obs_data_get_array(settings, key)
        local array = settings[key]
        if array then env.refs.arrays = env.refs.arrays + 1 end
        return array
    end
    function obs.obs_data_array_release() env.refs.arrays = env.refs.arrays - 1 end
    function obs.obs_data_set_array(settings, key, array) settings[key] = array end
    function obs.obs_hotkey_register_frontend(name, label, callback)
        assert(type(callback) == "function")
        env.registered[name] = {callback = callback, label = label}
        return name
    end
    function obs.obs_hotkey_load(id, array) assert(env.registered[id]); env.loaded = env.loaded + 1 end
    function obs.obs_hotkey_save(id) assert(env.registered[id]); env.refs.arrays = env.refs.arrays + 1; return {id = id} end
    function obs.obs_hotkey_unregister(callback)
        assert(type(callback) == "function", "Lua unregister must use the callback, not ID")
        env.unregistered = env.unregistered + 1
    end
    function obs.obs_properties_create() return {} end
    function obs.obs_properties_get(props, key) return props[key] end
    function obs.obs_properties_add_list(props, key, label) props[key] = {label = label, entries = {}} end
    function obs.obs_properties_add_text(props, key, text) props[key] = {description = text} end
    function obs.obs_properties_add_button(props, key, text, callback) props[key] = {callback = callback} end
    function obs.obs_property_set_description(property, text) property.description = text end
    function obs.obs_property_list_clear(property) property.entries = {} end
    function obs.obs_property_list_add_string(property, name, value) table.insert(property.entries, {name = name, value = value}) end
    function obs.obs_enum_sources()
        env.refs.lists = env.refs.lists + 1
        local sources = {}; for _, source in pairs(env.sources) do sources[#sources + 1] = source end
        return sources
    end
    function obs.source_list_release() env.refs.lists = env.refs.lists - 1 end
    env.obs = obs
    obslua = obs
    dofile("obs/pulse-controls.lua")
    env.settings = {source_uuid = target}
    if options.saved then env.settings.hotkey_increment = {key = "fixture"} end
    script_defaults(env.settings)
    script_load(env.settings)
    env.props = script_properties()
    function env.press(action, pressed) env.registered["pulse_meter." .. action].callback(pressed) end
    function env.tap(action) env.press(action, true); env.press(action, false) end
    function env.button(name) env.props[name].callback(env.props, env.props[name]) end
    function env.status() env.button("last_status"); return env.props.status.description end
    function env.balanced() for name, count in pairs(env.refs) do assert(count == 0, name .. " reference imbalance: " .. count) end end
    return env
end

check("No target is chosen or commanded on load; no default key bindings", function()
    local env = boot(nil)
    env.tap("increment")
    equal(#env.events, 0); equal(env.loaded, 0); equal(env.settings.source_uuid, "")
    assert(env.status():find("Choose a local")); env.balanced()
end)
check("Three exact fixed commands target only the chosen source UUID", function()
    local env = boot("a")
    for _, action in ipairs({"increment", "decrement", "reset"}) do
        env.tap(action)
        local event = env.events[#env.events]
        equal(event.uuid, "a"); equal(event.eventName, "pulse-meter-control-v1")
        equal(event.jsonString, '{"schema":1,"action":"' .. action .. '"}')
    end
    equal(#env.events, 3); assert(env.status():find("not acknowledged")); env.balanced()
end)
check("Held key repeats and key release cannot double-apply a command", function()
    local env = boot("a")
    env.press("increment", false); equal(#env.events, 0)
    for _ = 1, 100 do env.press("increment", true) end
    equal(#env.events, 1)
    env.press("increment", false); env.tap("increment"); equal(#env.events, 2); env.balanced()
end)
check("Missing, wrong-type, remote and non-showing targets safely refuse", function()
    for _, target in ipairs({"missing", "text", "remote", "a"}) do
        local env = boot(target)
        if target == "a" then env.sources.a.showing = false end
        env.tap("increment"); equal(#env.events, 0); env.balanced()
    end
end)
check("UUID survives rename and never retargets by a reused source name", function()
    local env = boot("a")
    env.sources.a.name = "Renamed PULSE"
    env.sources.b.name = "PULSE A"
    env.tap("increment"); equal(env.events[1].uuid, "a")
    env.sources.a = nil; env.tap("increment"); equal(#env.events, 1)
    assert(env.status():find("missing")); env.balanced()
end)
check("Changing target does not send commands and only affects later actions", function()
    local env = boot("a")
    script_update({source_uuid = "b"}); equal(#env.events, 0)
    env.tap("reset"); equal(env.events[1].uuid, "b"); env.balanced()
end)
check("Hidden-source commands are not queued or replayed when showing resumes", function()
    local env = boot("a")
    env.sources.a.showing = false; env.tap("increment")
    env.sources.a.showing = true; equal(#env.events, 0)
    env.tap("increment"); equal(#env.events, 1); env.balanced()
end)
check("Missing APIs and absent handler/procedure fail without leaked references", function()
    local env = boot("a")
    env.obs.obs_get_source_by_uuid = nil; env.tap("increment")
    equal(#env.events, 0); assert(env.status():find("Unsupported")); env.balanced()
    for _, options in ipairs({{no_handler = true}, {no_procedure = true}}) do
        env = boot("a", options); env.tap("increment"); equal(#env.events, 0); env.balanced()
    end
end)
check("Procedure errors release all owned objects without automatic retry", function()
    local env = boot("a", {api_error = true})
    env.tap("increment"); equal(#env.events, 0); equal(#env.logs, 1)
    assert(env.status():find("API error")); env.balanced()
end)
check("UI buttons use the same target, validation and fixed commands", function()
    local env = boot("a")
    env.button("test_increment"); env.button("test_decrement"); env.button("test_reset")
    equal(#env.events, 3); equal(env.events[3].jsonString, '{"schema":1,"action":"reset"}')
    env.sources.a.settings.is_local_file = false; env.button("test_increment")
    equal(#env.events, 3); env.balanced()
end)
check("Source refresh lists only browsers with UUID values and preserves missing target", function()
    local env = boot("a")
    local entries = env.props.source_uuid.entries
    equal(entries[1].value, ""); equal(#entries, 4)
    for _, entry in ipairs(entries) do assert(entry.value ~= "text") end
    env.sources.a = nil; env.button("refresh")
    local found = false
    for _, entry in ipairs(env.props.source_uuid.entries) do
        if entry.value == "a" then found = true; assert(entry.name:find("missing")) end
    end
    assert(found); equal(#env.events, 0); env.balanced()
end)
check("Hotkey load/save releases arrays; unload unregisters all callbacks", function()
    local env = boot("a", {saved = true})
    equal(env.loaded, 1)
    script_save(env.settings)
    for _, action in ipairs({"increment", "decrement", "reset"}) do assert(env.settings["hotkey_" .. action]) end
    script_unload(); equal(env.unregistered, 3); env.balanced()
end)

print("\n" .. groups .. " Lua mock groups passed with " .. _VERSION .. ". OBS and LuaJIT bindings were not run.")
