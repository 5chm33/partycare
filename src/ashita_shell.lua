local AshitaShell = {};
local ResourceStyle = require('src.resource_style');

local required_imgui = nil;
local required_imgui_error = nil;
do
    local ok, library_or_error = pcall(require, 'imgui');
    if ok and type(library_or_error) == 'table' then required_imgui = library_or_error; else required_imgui_error = library_or_error; end
end

local window_initialized = {main = false, settings = false};
local edit_buffers = {};
local settings_tab = 'general';
local settings_feedback = nil;

local function get_imgui()
    if type(_G.imgui) == 'table' then return _G.imgui; end
    return required_imgui;
end

local function percent_text(current, maximum)
    if maximum <= 0 then return '—'; end
    return string.format('%d / %d (%.0f%%)', current, maximum, current / maximum * 100);
end

local function member_label(member, selected)
    local marker = selected and '> ' or '';
    local status = member.status ~= '' and ('  ' .. member.status) or '';
    return string.format('%s%s%s', marker, member.name, status);
end

local function mutate(model, callback)
    local updated, errors = model:update_config(callback);
    return updated, errors;
end

local function toggle_button(imgui, label, value, on_click)
    if imgui.Button(label .. ': ' .. (value and 'ON' or 'OFF')) then on_click(not value); return true; end
    return false;
end

local function stepper(imgui, label, value, minimum, maximum, step, on_change)
    imgui.Text(string.format('%s: %.0f', label, value));
    if imgui.Button('-##' .. label) then on_change(math.max(minimum, value - step)); return true; end
    imgui.SameLine();
    if imgui.Button('+##' .. label) then on_change(math.min(maximum, value + step)); return true; end
    return false;
end

local function edit_text(imgui, key, label, value, on_change)
    local buffer = edit_buffers[key];
    if not buffer then
        buffer = {value}; edit_buffers[key] = buffer;
    elseif buffer[1] ~= value and (type(imgui.IsItemActive) ~= 'function' or not imgui.IsItemActive()) then
        buffer[1] = value;
    end
    if imgui.InputText(label, buffer, 64) and type(buffer[1]) == 'string' and buffer[1]:match('%S') then
        on_change(buffer[1]); return true;
    end
    return false;
end

local function initialize_window(imgui, window_key, x, y, width, height)
    if window_initialized[window_key] then return; end
    imgui.SetNextWindowPos({x, y});
    imgui.SetNextWindowSize({width, height});
    window_initialized[window_key] = true;
end

local function window_position(imgui)
    local first, second = imgui.GetWindowPos();
    if type(first) == 'table' then return first[1] or first.x, first[2] or first.y; end
    return first, second;
end

local function capture_position(model, function_name, imgui)
    if type(imgui.GetWindowPos) ~= 'function' then return false; end
    local x, y = window_position(imgui);
    if type(x) ~= 'number' or type(y) ~= 'number' then return false; end
    return model[function_name](model, x, y) == true;
end

local function capture_size(model, imgui)
    if type(imgui.GetWindowSize) ~= 'function' then return false; end
    local first, second = imgui.GetWindowSize();
    local width, height;
    if type(first) == 'table' then width, height = first[1] or first.x, first[2] or first.y; else width, height = first, second; end
    if type(width) ~= 'number' or type(height) ~= 'number' then return false; end
    return model:capture_window_size(width, height) == true;
end

local function set_font_scale(imgui, scale)
    if type(imgui.SetWindowFontScale) == 'function' then imgui.SetWindowFontScale(scale); end
end

local function dummy(imgui, width, height)
    if type(imgui.Dummy) == 'function' then imgui.Dummy({width, height}); else imgui.Text(' '); end
end

local function styled_progress(imgui, fraction, size, label, color)
    local pushed = false;
    local plot_color = rawget(_G, 'ImGuiCol_PlotHistogram');
    if plot_color and type(imgui.PushStyleColor) == 'function' and type(imgui.PopStyleColor) == 'function' then
        imgui.PushStyleColor(plot_color, color);
        pushed = true;
    end
    imgui.ProgressBar(fraction, size, label);
    if pushed then imgui.PopStyleColor(1); end
end

local function begin_group(imgui)
    if type(imgui.BeginGroup) == 'function' then imgui.BeginGroup(); return true; end
    return false;
end

local function end_group(imgui, opened)
    if opened and type(imgui.EndGroup) == 'function' then imgui.EndGroup(); end
end

local function set_window_alpha(imgui, alpha)
    if type(imgui.SetNextWindowBgAlpha) == 'function' then imgui.SetNextWindowBgAlpha(alpha); end
end

function AshitaShell.available()
    local imgui = get_imgui();
    return type(imgui) == 'table' and type(imgui.Begin) == 'function' and type(imgui.End) == 'function';
end

function AshitaShell.visibility_status()
    local imgui = get_imgui();
    if not AshitaShell.available() then return false, 'Ashita ImGui module could not be loaded: ' .. tostring(required_imgui_error or 'binding unavailable'); end
    if type(imgui.GetHide) == 'function' and imgui.GetHide() then return false, 'Ashita ImGui objects are globally hidden'; end
    return true, 'ready';
end

function AshitaShell.force_visible()
    local imgui = get_imgui();
    if type(imgui) == 'table' and type(imgui.SetHide) == 'function' then imgui.SetHide(false); end
    if AshitaShell.available() then return true, nil; end
    return false, 'Ashita ImGui visibility control is unavailable';
end

function AshitaShell.reset_window_positions()
    window_initialized = {main = false, settings = false};
    edit_buffers = {};
    settings_tab = 'general';
    settings_feedback = nil;
end

local MOUSE_BUTTONS = {left = 0, right = 1, middle = 2};

local function member_click(imgui, model, member, now, width, height)
    local pressed = imgui.Button(member_label(member, tostring(model:view().selected_member_id) == tostring(member.id)) .. '##member_' .. tostring(member.id), {width, height});
    local button = nil;
    if type(imgui.IsItemClicked) == 'function' then
        for name, code in pairs(MOUSE_BUTTONS) do if imgui.IsItemClicked(code) then button = name; break; end end
    elseif pressed then
        button = 'left';
    end
    if not button then return false; end
    local intent = model:request_direct_click(member.id, button, now);
    if not intent then model:select_member(member.id); end
    return true;
end

local function tab_button(imgui, name, label)
    local text = (settings_tab == name and '[' .. label .. ']' or label) .. '##partycare_tab_' .. name;
    if imgui.Button(text) then settings_tab = name; return true; end
    return false;
end

local function save_settings(model, callbacks)
    if type(callbacks.on_save) ~= 'function' then settings_feedback = 'Save handler unavailable.'; return false; end
    local saved, save_error = callbacks.on_save(model:export_config());
    settings_feedback = saved and 'Saved settings successfully.' or ('Save failed: ' .. tostring(save_error or 'unknown error'));
    return saved == true;
end

local function close_settings(model)
    mutate(model, function(candidate) candidate.ui.settings_open = false; end);
    settings_tab = 'general';
end

local function render_general_tab(imgui, model, config)
    local changed = false;
    imgui.Text('Grid Layout');
    if toggle_button(imgui, 'Lock Panel Position', config.ui.locked, function(value) mutate(model, function(candidate) candidate.ui.locked = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Minimal Live Frame', config.ui.minimal_mode, function(value) mutate(model, function(candidate) candidate.ui.minimal_mode = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Adaptive Card Scaling', config.ui.adaptive_scale, function(value) mutate(model, function(candidate) candidate.ui.adaptive_scale = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Show MP Bar', config.ui.show_mp, function(value) mutate(model, function(candidate) candidate.ui.show_mp = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Show Status Text', config.ui.show_status, function(value) mutate(model, function(candidate) candidate.ui.show_status = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Show Remedy Button', config.ui.show_remedy_button, function(value) mutate(model, function(candidate) candidate.ui.show_remedy_button = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Show Legacy Spell Bar', config.ui.show_action_bar, function(value) mutate(model, function(candidate) candidate.ui.show_action_bar = value; end); end) then changed = true; end
    imgui.Separator();
    if stepper(imgui, 'Grid Columns', config.ui.grid_columns, 1, 3, 1, function(value) mutate(model, function(candidate) candidate.ui.grid_columns = value; end); window_initialized.main = false; end) then changed = true; end
    if stepper(imgui, 'Card Width', config.ui.card_width, 140, 360, 10, function(value) mutate(model, function(candidate) candidate.ui.card_width = value; end); window_initialized.main = false; end) then changed = true; end
    if stepper(imgui, 'Card Height', config.ui.card_height, 52, 120, 2, function(value) mutate(model, function(candidate) candidate.ui.card_height = value; end) end) then changed = true; end
    if stepper(imgui, 'Transparency', config.ui.background_alpha * 100, 15, 95, 5, function(value) mutate(model, function(candidate) candidate.ui.background_alpha = value / 100; end); end) then changed = true; end
    if not config.ui.adaptive_scale then
        if stepper(imgui, 'Text Scale', config.ui.font_scale * 100, 60, 180, 5, function(value) mutate(model, function(candidate) candidate.ui.font_scale = value / 100; end); end) then changed = true; end
    end
    if stepper(imgui, 'Warning HP', config.thresholds.warning_hp, config.thresholds.critical_hp + 1, 100, 5, function(value) mutate(model, function(candidate) candidate.thresholds.warning_hp = value; end); end) then changed = true; end
    if stepper(imgui, 'Critical HP', config.thresholds.critical_hp, 0, config.thresholds.warning_hp - 1, 5, function(value) mutate(model, function(candidate) candidate.thresholds.critical_hp = value; end); end) then changed = true; end
    imgui.Separator();
    if imgui.Button('Reset Both Windows') then model:reset_layout(); AshitaShell.reset_window_positions(); changed = true; end
    imgui.TextDisabled('Drag either title bar to move it. Position saves automatically.');
    return changed;
end

local function render_direct_tab(imgui, model, config)
    local changed = false;
    local armed = config.direct_click.enabled and config.live_test.manual_dispatch_enabled and not config.live_test.emergency_stop;
    imgui.Text('Direct Party-Frame Clicks');
    imgui.TextDisabled(armed and 'ACTIVE: one deliberate frame click uses its configured binding.' or 'INACTIVE: frame clicks select members only.');
    if toggle_button(imgui, 'Enable Direct Click Mode', config.direct_click.enabled, function(value)
        mutate(model, function(candidate)
            candidate.direct_click.enabled = value;
            candidate.live_test.manual_dispatch_enabled = value;
            candidate.live_test.emergency_stop = not value;
        end);
    end) then changed = true; end
    for _, button in ipairs({'left', 'right', 'middle'}) do
        local binding = config.direct_click[button];
        imgui.Separator(); imgui.Text(button:upper() .. ' CLICK');
        if edit_text(imgui, 'direct_spell_' .. button, 'Spell##direct_' .. button, binding.spell, function(value) mutate(model, function(candidate) candidate.direct_click[button].spell = value; end); end) then changed = true; end
        if toggle_button(imgui, 'Enable ' .. button, binding.enabled, function(value) mutate(model, function(candidate) candidate.direct_click[button].enabled = value; end); end) then changed = true; end
    end
    return changed;
end

local function render_spells_tab(imgui, model, config)
    local changed = false;
    imgui.Text('Optional Spell Bar');
    imgui.TextDisabled('Enable the legacy spell bar only if you want extra manual action buttons below the grid.');
    for _, action_key in ipairs({'primary', 'secondary', 'emergency', 'refresh'}) do
        local action = config.actions[action_key];
        imgui.Separator(); imgui.Text(action_key:upper());
        if edit_text(imgui, 'action_label_' .. action_key, 'Label##' .. action_key, action.label, function(value) mutate(model, function(candidate) candidate.actions[action_key].label = value; end); end) then changed = true; end
        if edit_text(imgui, 'action_spell_' .. action_key, 'Spell##' .. action_key, action.spell, function(value) mutate(model, function(candidate) candidate.actions[action_key].spell = value; end); end) then changed = true; end
        if toggle_button(imgui, 'Enable ' .. action_key, action.enabled, function(value) mutate(model, function(candidate) candidate.actions[action_key].enabled = value; end); end) then changed = true; end
    end
    return changed;
end

local function render_remedies_tab(imgui, model, config)
    local changed = false;
    imgui.Text('Debuff Remedy Rules');
    imgui.TextDisabled('Each Remedy click resolves one highest-priority recognized active debuff.');
    for _, rule_key in ipairs({'paralyze', 'gravity', 'slow', 'silence', 'blind', 'poison', 'bio', 'dia'}) do
        local rule = config.remedies[rule_key];
        imgui.Separator(); imgui.Text(rule_key:upper() .. ' — priority ' .. tostring(rule.priority));
        if edit_text(imgui, 'remedy_spell_' .. rule_key, 'Spell##remedy_' .. rule_key, rule.spell, function(value) mutate(model, function(candidate) candidate.remedies[rule_key].spell = value; end); end) then changed = true; end
        if toggle_button(imgui, 'Enable ' .. rule_key, rule.enabled, function(value) mutate(model, function(candidate) candidate.remedies[rule_key].enabled = value; end); end) then changed = true; end
        if stepper(imgui, 'Priority ' .. rule_key, rule.priority, 0, 200, 5, function(value) mutate(model, function(candidate) candidate.remedies[rule_key].priority = value; end); end) then changed = true; end
    end
    return changed;
end

local function render_settings_window(imgui, model, callbacks)
    local changed = false;
    local view = model:view();
    local config = view.config;
    if not config.ui.settings_open then return false; end

    initialize_window(imgui, 'settings', config.ui.settings_x, config.ui.settings_y, 430, 0);
    local open = imgui.Begin('PartyCare Settings##grid');
    if open then
        changed = capture_position(model, 'capture_settings_position', imgui) or changed;
        view = model:view(); config = view.config;
        if imgui.Button('Save', {80, 0}) then save_settings(model, callbacks); end
        imgui.SameLine();
        if imgui.Button('Save & Close', {120, 0}) then save_settings(model, callbacks); close_settings(model); changed = true; end
        imgui.SameLine();
        if imgui.Button('Close', {80, 0}) then close_settings(model); changed = true; end
        if settings_feedback then imgui.TextDisabled(settings_feedback); end
        imgui.Separator();
        if tab_button(imgui, 'general', 'General') then changed = true; end
        imgui.SameLine(); if tab_button(imgui, 'direct', 'Direct Click') then changed = true; end
        imgui.SameLine(); if tab_button(imgui, 'spells', 'Spells') then changed = true; end
        imgui.SameLine(); if tab_button(imgui, 'remedies', 'Remedies') then changed = true; end
        imgui.Separator();
        if settings_tab == 'general' then changed = render_general_tab(imgui, model, config) or changed;
        elseif settings_tab == 'direct' then changed = render_direct_tab(imgui, model, config) or changed;
        elseif settings_tab == 'spells' then changed = render_spells_tab(imgui, model, config) or changed;
        elseif settings_tab == 'remedies' then changed = render_remedies_tab(imgui, model, config) or changed;
        end
    end
    imgui.End();
    return changed;
end

local function grid_window_width(config)
    return config.ui.grid_columns * config.ui.card_width + (config.ui.grid_columns - 1) * 8 + 20;
end

local function render_member_card(imgui, model, member, now, config)
    local card_width = config.ui.card_width;
    local group_open = begin_group(imgui);
    local clicked = member_click(imgui, model, member, now, card_width, config.ui.member_height);
    local latest = model:view();
    if clicked then latest = model:view(); end
    local hp_color = ResourceStyle.hp_color(member.hp_percent / 100, config.thresholds.warning_hp, config.thresholds.critical_hp);
    styled_progress(imgui, member.hp_percent / 100, {card_width, 10}, ResourceStyle.bar_label('HP', member.hp, member.hp_max, config.ui.font_scale), hp_color);
    if config.ui.show_mp and member.mp_max > 0 then
        local mp_color = ResourceStyle.mp_color(member.mp_percent / 100);
        styled_progress(imgui, member.mp_percent / 100, {card_width, 8}, ResourceStyle.bar_label('MP', member.mp, member.mp_max, config.ui.font_scale), mp_color);
    end
    local recommendation = member.remedy_recommendation;
    if config.ui.show_remedy_button and recommendation then
        local remedy_label = 'Remedy: ' .. recommendation.spell .. '##remedy_' .. tostring(member.id);
        if imgui.Button(remedy_label, {card_width, 16}) then
            model:select_member(member.id);
            model:request_remedy(now);
        end
        if type(imgui.IsItemHovered) == 'function' and imgui.IsItemHovered() and type(imgui.SetTooltip) == 'function' then
            imgui.SetTooltip('Priority ' .. tostring(recommendation.priority) .. ': ' .. recommendation.debuff .. ' → ' .. recommendation.spell);
        end
    elseif config.ui.show_status and member.status ~= '' then
        imgui.TextDisabled(member.status);
    else
        dummy(imgui, card_width, 16);
    end
    end_group(imgui, group_open);
end

function AshitaShell.render(model, now, callbacks)
    local ready, reason = AshitaShell.visibility_status();
    if not ready then return nil, reason, false; end
    if type(model) ~= 'table' or type(model.view) ~= 'function' then return nil, 'valid panel model is required', false; end

    local imgui = get_imgui();
    callbacks = callbacks or {};
    local changed = false;
    local view = model:view();
    local config = view.config;
    if not config.ui.visible then return {}, nil, false; end

    set_window_alpha(imgui, config.ui.background_alpha);
    initialize_window(imgui, 'main', config.ui.x, config.ui.y, grid_window_width(config), config.ui.height);
    local titlebar_flag = config.ui.minimal_mode and _G.ImGuiWindowFlags_NoTitleBar or nil;
    local open;
    if titlebar_flag then open = imgui.Begin('PartyCare##grid', true, titlebar_flag); else open = imgui.Begin('PartyCare##grid'); end
    if open then
        if not config.ui.locked then changed = capture_position(model, 'capture_window_position', imgui) or changed; end
        changed = capture_size(model, imgui) or changed;
        view = model:view(); config = view.config;
        set_font_scale(imgui, config.ui.font_scale);
        if not config.ui.minimal_mode then
            if imgui.Button(config.ui.settings_open and 'Close Settings' or 'Settings', {-1, 0}) then
                mutate(model, function(candidate) candidate.ui.settings_open = not candidate.ui.settings_open; end);
                if not config.ui.settings_open then settings_tab = 'general'; end
                changed = true;
            end
            local armed = config.direct_click.enabled and config.live_test.manual_dispatch_enabled and not config.live_test.emergency_stop;
            imgui.TextDisabled(armed and 'DIRECT CLICK: ACTIVE' or 'DIRECT CLICK: OFF');
            imgui.Separator();
        end

        for index, member in ipairs(view.members) do
            render_member_card(imgui, model, member, now, config);
            if index % config.ui.grid_columns ~= 0 and index < #view.members then imgui.SameLine(); end
        end

        if config.ui.show_action_bar then
            imgui.Separator();
            for _, action_key in ipairs({'primary', 'secondary', 'emergency', 'refresh'}) do
                local action = config.actions[action_key];
                if action.enabled then
                    if imgui.Button(action.label .. '##action_' .. action_key) then model:request_action(action_key, now); end
                    imgui.SameLine();
                end
            end
            imgui.NewLine();
        end
    end
    imgui.End();
    changed = render_settings_window(imgui, model, callbacks) or changed;
    return model:drain_audit(), nil, changed;
end

return AshitaShell;
