addon.name = 'partycare';
addon.author = 'Schmeee';
addon.version = '1.2.1';
addon.desc = 'Manual party and alliance healing and remedy panel for Ashita.';

local Config = require('src.config');
local PanelModel = require('src.panel_model');
local AshitaShell = require('src.ashita_shell');
local SettingsStore = require('src.settings_store');
local PartyProvider = require('src.ashita_party_provider');
local ManualDispatchAdapter = require('src.manual_dispatch_adapter');
local Commands = require('src.commands');

local state = {
    model = nil,
    now = 0,
    next_snapshot_at = 0,
    settings_path = addon.path .. '/settings.lua',
    dirty_at = nil,
    last_render_error = nil,
    last_party_error = nil,
    dispatch_adapter = nil,
};

local function chat(message)
    print('[PartyCare] ' .. message);
end

local function load_settings()
    local file = io.open(state.settings_path, 'r');
    if not file then return Config.DEFAULT; end
    local source = file:read('*a'); file:close();
    local loader = loadstring or load;
    local chunk, load_error = loader(source, '@' .. state.settings_path);
    if not chunk then chat('Settings could not be read; using defaults: ' .. tostring(load_error)); return Config.DEFAULT; end
    if setfenv then setfenv(chunk, {}); end
    local ok, raw = pcall(chunk);
    if not ok then chat('Settings could not be loaded; using defaults.'); return Config.DEFAULT; end
    local config, errors = Config.validate(raw);
    if not config then chat('Settings are invalid; using defaults: ' .. table.concat(errors, '; ')); return Config.DEFAULT; end
    return config;
end

local function save_settings()
    if not state.model then return false, 'panel model is unavailable'; end
    local saved, save_error = SettingsStore.save(state.settings_path, state.model:export_config());
    if not saved then chat('Unable to save settings: ' .. tostring(save_error)); return false, save_error; end
    state.dirty_at = nil;
    return true, nil;
end

local function mark_dirty() state.dirty_at = state.now; end

local function update_members()
    local members, provider_error = PartyProvider.snapshot();
    if not members then
        state.model:update_members({});
        if state.last_party_error ~= provider_error then state.last_party_error = provider_error; chat('Party data unavailable: ' .. tostring(provider_error)); end
        return;
    end
    state.last_party_error = nil;
    local updated, errors = state.model:update_members(members);
    if not updated then chat('Party data was rejected: ' .. table.concat(errors, '; ')); end
end

local function show_panel(open_settings)
    state.model:set_ui_value('visible', true);
    AshitaShell.force_visible();
    if open_settings then state.model:set_ui_value('settings_open', true); end
    mark_dirty();
end

local function set_dispatch(enabled)
    local updated, errors = state.model:update_config(function(candidate)
        candidate.live_test.manual_dispatch_enabled = enabled;
        candidate.live_test.emergency_stop = not enabled;
    end);
    if not updated then chat('Unable to update dispatch state: ' .. table.concat(errors, '; ')); return; end
    mark_dirty();
    chat(enabled and 'Manual actions enabled.' or 'Manual actions disabled.');
end

local function handle_command(parsed)
    if type(parsed) ~= 'table' then return false; end
    local action = parsed.action;
    if action == 'show' then show_panel(false);
    elseif action == 'hide' then state.model:set_ui_value('visible', false); mark_dirty();
    elseif action == 'toggle' then state.model:set_ui_value('visible', not state.model.config.ui.visible); mark_dirty();
    elseif action == 'config' then show_panel(true);
    elseif action == 'reset' then state.model:reset_layout(); AshitaShell.reset_window_positions(); show_panel(true); mark_dirty();
    elseif action == 'save' then if save_settings() then chat('Settings saved.'); end
    elseif action == 'dispatch' then
        if parsed.argument == 'on' then set_dispatch(true) elseif parsed.argument == 'off' then set_dispatch(false) else chat('Usage: /partycare dispatch on|off'); end
    elseif action == 'status' then
        local view = state.model:view();
        chat(string.format('Panel: %s; members: %d; direct click: %s; actions: %s', tostring(view.config.ui.visible), #view.members, tostring(view.config.direct_click.enabled), tostring(view.config.live_test.manual_dispatch_enabled and not view.config.live_test.emergency_stop)));
    else
        chat('Commands: /partycare show|hide|toggle|config|reset|save|dispatch on|dispatch off|status');
    end
    return true;
end

ashita.events.register('load', 'partycare_load', function()
    local model, errors = PanelModel.new(load_settings());
    if not model then chat('Unable to initialize: ' .. table.concat(errors, '; ')); return; end
    state.model = model;
    local chat_manager = nil;
    if AshitaCore ~= nil then
        local manager_ok, manager_or_error = pcall(function() return AshitaCore:GetChatManager(); end);
        if manager_ok then chat_manager = manager_or_error; end
    end
    state.dispatch_adapter = ManualDispatchAdapter.new(chat_manager);
    state.model:set_ui_value('visible', true);
    local made_visible, visibility_error = AshitaShell.force_visible();
    if not made_visible then chat('ImGui visibility check: ' .. tostring(visibility_error)); end
    update_members();
    chat('Loaded. Use /pc to open settings.');
end);

ashita.events.register('command', 'partycare_command', function(e)
    local parsed = Commands.parse(e and e.command);
    if not parsed then return; end
    e.blocked = true;
    handle_command(parsed);
end);

ashita.events.register('d3d_present', 'partycare_draw', function()
    if not state.model then return; end
    state.now = state.now + (1 / 60);
    if state.now >= state.next_snapshot_at then state.next_snapshot_at = state.now + 0.20; update_members(); end
    local ok, audit, error_message, changed = pcall(AshitaShell.render, state.model, state.now, {on_save = function() return save_settings(); end});
    if not ok then
        if state.last_render_error ~= audit then state.last_render_error = audit; chat('Render error: ' .. tostring(audit)); end
        return;
    end
    if error_message then
        if state.last_render_error ~= error_message then state.last_render_error = error_message; chat('Panel unavailable: ' .. error_message); end
        return;
    end
    state.last_render_error = nil;
    if changed then mark_dirty(); end
    if state.dirty_at and state.now - state.dirty_at >= 1 then save_settings(); end
    for _, event in ipairs(audit or {}) do
        if event.kind == 'MANUAL_CLICK_CAST_REQUEST' then
            local view = state.model:view();
            -- Direct actions are intentionally quiet; the game cast and party card provide the feedback.
            state.dispatch_adapter:dispatch(event, view.config.live_test);
        end
    end
end);
