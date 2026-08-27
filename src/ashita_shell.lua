local AshitaShell = {};
local ResourceStyle = require('src.resource_style');

local required_imgui = nil;
local required_imgui_error = nil;
do
    local ok, library_or_error = pcall(require, 'imgui');
    if ok and type(library_or_error) == 'table' then required_imgui = library_or_error; else required_imgui_error = library_or_error; end
end

local window_initialized = {main = false, settings = false, enemy = false};
local main_layout_signature = nil;
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

local function push_window_background(imgui, alpha)
    local window_bg = rawget(_G, 'ImGuiCol_WindowBg');
    if window_bg and type(imgui.PushStyleColor) == 'function' and type(imgui.PopStyleColor) == 'function' then
        -- Explicitly style the window background because some Ashita themes ignore SetNextWindowBgAlpha.
        imgui.PushStyleColor(window_bg, {0.025, 0.035, 0.055, alpha});
        return true;
    end
    return false;
end

local function pulsing_remedy_button(imgui, label, size, now)
    local pushed = false;
    local button_color = rawget(_G, 'ImGuiCol_Button');
    if button_color and type(imgui.PushStyleColor) == 'function' and type(imgui.PopStyleColor) == 'function' then
        local pulse = (math.sin((tonumber(now) or 0) * 3.5) + 1) / 2;
        -- Soft amber modulation draws attention while keeping the card readable against a transparent frame.
        imgui.PushStyleColor(button_color, {0.58 + pulse * 0.16, 0.29 + pulse * 0.10, 0.07, 0.76 + pulse * 0.16});
        pushed = true;
    end
    local pressed = imgui.Button(label, size);
    if pushed then imgui.PopStyleColor(1); end
    return pressed;
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
    window_initialized = {main = false, settings = false, enemy = false};
    main_layout_signature = nil;
    edit_buffers = {};
    settings_tab = 'general';
    settings_feedback = nil;
end

local MOUSE_BUTTONS = {left = 0, right = 1, middle = 2, mouse4 = 3, mouse5 = 4};
local last_wheel_dispatch_at = -1;

local function hovered_wheel_direction(imgui)
    if type(imgui.IsItemHovered) ~= 'function' or not imgui.IsItemHovered() or type(imgui.GetIO) ~= 'function' then return nil; end
    local ok, io = pcall(function() return imgui.GetIO(); end);
    local wheel = ok and io ~= nil and tonumber(io.MouseWheel or io.mouse_wheel) or nil;
    if wheel and wheel > 0 then return 'wheel_up'; end
    if wheel and wheel < 0 then return 'wheel_down'; end
    return nil;
end

local function member_click(imgui, model, member, now, width, height, upkeep_alert_kind, pulse_alert)
    local pushed_count = 0;
    if (upkeep_alert_kind or pulse_alert) and type(imgui.PushStyleColor) == 'function' and type(imgui.PopStyleColor) == 'function' then
        local pulse = (math.sin((tonumber(now) or 0) * 4.0) + 1) / 2;
        local button_color = rawget(_G, 'ImGuiCol_Button');
        local hover_color = rawget(_G, 'ImGuiCol_ButtonHovered');
        local active_color = rawget(_G, 'ImGuiCol_ButtonActive');
        local text_color = rawget(_G, 'ImGuiCol_Text');
        if pulse_alert then
            if button_color then imgui.PushStyleColor(button_color, {0.42 + pulse * 0.45, 0.03, 0.03, 0.88 + pulse * 0.12}); pushed_count = pushed_count + 1; end
            if hover_color then imgui.PushStyleColor(hover_color, {0.96, 0.16, 0.12, 1.00}); pushed_count = pushed_count + 1; end
            if active_color then imgui.PushStyleColor(active_color, {0.35, 0.01, 0.01, 1.00}); pushed_count = pushed_count + 1; end
            if text_color then imgui.PushStyleColor(text_color, {1.00, 0.18 + pulse * 0.20, 0.18 + pulse * 0.10, 1.00}); pushed_count = pushed_count + 1; end
        elseif upkeep_alert_kind == 'expiring' then
            -- Refresh has visual priority: its final 15-second cue is purple.
            if button_color then imgui.PushStyleColor(button_color, {0.18 + pulse * 0.26, 0.08 + pulse * 0.08, 0.42 + pulse * 0.34, 0.88 + pulse * 0.12}); pushed_count = pushed_count + 1; end
            if hover_color then imgui.PushStyleColor(hover_color, {0.42, 0.24, 0.72, 1.00}); pushed_count = pushed_count + 1; end
            if active_color then imgui.PushStyleColor(active_color, {0.16, 0.06, 0.34, 1.00}); pushed_count = pushed_count + 1; end
            if text_color then imgui.PushStyleColor(text_color, {0.94, 0.80 + pulse * 0.20, 1.00, 1.00}); pushed_count = pushed_count + 1; end
        elseif upkeep_alert_kind == 'haste_expiring' then
            -- Haste is visible only after the Refresh cue is clear; use yellow.
            if button_color then imgui.PushStyleColor(button_color, {0.48 + pulse * 0.38, 0.30 + pulse * 0.32, 0.03, 0.86 + pulse * 0.14}); pushed_count = pushed_count + 1; end
            if hover_color then imgui.PushStyleColor(hover_color, {0.98, 0.78, 0.12, 1.00}); pushed_count = pushed_count + 1; end
            if active_color then imgui.PushStyleColor(active_color, {0.50, 0.31, 0.01, 1.00}); pushed_count = pushed_count + 1; end
            if text_color then imgui.PushStyleColor(text_color, {1.00, 0.96, 0.70 + pulse * 0.30, 1.00}); pushed_count = pushed_count + 1; end
        elseif upkeep_alert_kind == 'haste_missing' then
            -- Confirmed missing Haste remains solid yellow until observed active.
            if button_color then imgui.PushStyleColor(button_color, {0.62, 0.42, 0.05, 0.96}); pushed_count = pushed_count + 1; end
            if hover_color then imgui.PushStyleColor(hover_color, {0.82, 0.60, 0.08, 1.00}); pushed_count = pushed_count + 1; end
            if active_color then imgui.PushStyleColor(active_color, {0.40, 0.25, 0.01, 1.00}); pushed_count = pushed_count + 1; end
            if text_color then imgui.PushStyleColor(text_color, {1.00, 0.92, 0.60, 1.00}); pushed_count = pushed_count + 1; end
        else
            -- Refresh is confirmed absent: a solid, darker purple stays visible
            -- until an observed reapplication clears the state.
            if button_color then imgui.PushStyleColor(button_color, {0.19, 0.08, 0.32, 0.96}); pushed_count = pushed_count + 1; end
            if hover_color then imgui.PushStyleColor(hover_color, {0.29, 0.13, 0.48, 1.00}); pushed_count = pushed_count + 1; end
            if active_color then imgui.PushStyleColor(active_color, {0.12, 0.04, 0.22, 1.00}); pushed_count = pushed_count + 1; end
            if text_color then imgui.PushStyleColor(text_color, {0.84, 0.70, 0.98, 1.00}); pushed_count = pushed_count + 1; end
        end
    end
    local pressed = imgui.Button(member_label(member, tostring(model:view().selected_member_id) == tostring(member.id)) .. '##member_' .. tostring(member.id), {width, height});
    if pushed_count > 0 then imgui.PopStyleColor(pushed_count); end
    -- Layout-preview cards are deliberately inert: they only show size, ordering, and grid flow.
    if member.layout_preview then return false; end
    local button = nil;
    if type(imgui.IsItemClicked) == 'function' then
        for _, name in ipairs({'left', 'right', 'middle', 'mouse4', 'mouse5'}) do
            if imgui.IsItemClicked(MOUSE_BUTTONS[name]) then button = name; break; end
        end
    end
    -- Some Ashita ImGui builds expose IsItemClicked but do not report Button's left-click activation through it.
    if not button and pressed then button = 'left'; end
    if not button then
        local wheel = hovered_wheel_direction(imgui);
        if wheel and now - last_wheel_dispatch_at >= 0.10 then button, last_wheel_dispatch_at = wheel, now; end
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
    if toggle_button(imgui, 'XIUI-Compatible Party Style', config.ui.xiui_style, function(value) mutate(model, function(candidate) candidate.ui.xiui_style = value; end); window_initialized.main = false; end) then changed = true; end
    if toggle_button(imgui, 'Pulse Names Missing Refresh', config.ui.refresh_pulse_enabled, function(value) mutate(model, function(candidate) candidate.ui.refresh_pulse_enabled = value; end); end) then changed = true; end
    if config.ui.refresh_pulse_enabled then
        if stepper(imgui, 'Refresh Alert MP Threshold', config.ui.refresh_min_mp, 0, 9999, 25, function(value) mutate(model, function(candidate) candidate.ui.refresh_min_mp = value; end); end) then changed = true; end
        if toggle_button(imgui, 'Pulse 15 Seconds Before Refresh Expires', config.ui.refresh_early_pulse_enabled, function(value) mutate(model, function(candidate) candidate.ui.refresh_early_pulse_enabled = value; end); end) then changed = true; end
        if config.ui.refresh_early_pulse_enabled then
            if stepper(imgui, 'Observed Refresh Duration', config.ui.refresh_duration_seconds, 30, 900, 5, function(value) mutate(model, function(candidate) candidate.ui.refresh_duration_seconds = value; end); end) then changed = true; end
            if stepper(imgui, 'Early Refresh Lead Time', config.ui.refresh_early_seconds, 1, math.max(1, config.ui.refresh_duration_seconds - 1), 1, function(value) mutate(model, function(candidate) candidate.ui.refresh_early_seconds = value; end); end) then changed = true; end
            imgui.TextDisabled('Starts when PartyCare first observes Refresh; missing-Refresh remains the fallback.');
        else
            imgui.TextDisabled('Pulses only for members above this maximum MP without a confirmed Refresh icon.');
        end
    end
    if toggle_button(imgui, 'Compact Debuff Alert Mode', config.ui.debuff_alert_mode, function(value) mutate(model, function(candidate) candidate.ui.debuff_alert_mode = value; candidate.ui.debuff_alert_preview = value; end); window_initialized.main = false; end) then changed = true; end
    if toggle_button(imgui, 'Pulse Names Missing Haste', config.ui.haste_pulse_enabled, function(value) mutate(model, function(candidate) candidate.ui.haste_pulse_enabled = value; end); end) then changed = true; end
    if config.ui.haste_pulse_enabled then
        if toggle_button(imgui, 'Pulse 15 Seconds Before Haste Expires', config.ui.haste_early_pulse_enabled, function(value) mutate(model, function(candidate) candidate.ui.haste_early_pulse_enabled = value; end); end) then changed = true; end
        if config.ui.haste_early_pulse_enabled then
            if stepper(imgui, 'Observed Haste Duration', config.ui.haste_duration_seconds, 30, 900, 5, function(value) mutate(model, function(candidate) candidate.ui.haste_duration_seconds = value; end); end) then changed = true; end
            if stepper(imgui, 'Early Haste Lead Time', config.ui.haste_early_seconds, 1, math.max(1, config.ui.haste_duration_seconds - 1), 1, function(value) mutate(model, function(candidate) candidate.ui.haste_early_seconds = value; end); end) then changed = true; end
            imgui.TextDisabled('Haste is yellow and appears only after the higher-priority Refresh cue is clear.');
        else
            imgui.TextDisabled('Shows solid yellow only when Haste is confirmed absent and usable.');
        end
    end
    if config.ui.debuff_alert_mode then
        if toggle_button(imgui, 'Show Compact Placement Preview', config.ui.debuff_alert_preview, function(value) mutate(model, function(candidate) candidate.ui.debuff_alert_preview = value; end); window_initialized.main = false; end) then changed = true; end
        imgui.TextDisabled('Idle alerts are fully hidden. Turn preview on only to position the compact alert box.');
    end
    if toggle_button(imgui, 'Enemy Dispel Compact Alert', config.ui.enemy_dispel_alert_mode, function(value) mutate(model, function(candidate) candidate.ui.enemy_dispel_alert_mode = value; candidate.ui.enemy_dispel_alert_preview = value; end); window_initialized.enemy = false; end) then changed = true; end
    if config.ui.enemy_dispel_alert_mode then
        if toggle_button(imgui, 'Show Enemy Dispel Placement Preview', config.ui.enemy_dispel_alert_preview, function(value) mutate(model, function(candidate) candidate.ui.enemy_dispel_alert_preview = value; end); window_initialized.enemy = false; end) then changed = true; end
        imgui.TextDisabled('Shows a party-engaged enemy when Dispel is usable; log-confirmed buffs are named. Select that enemy, then click manually.');
    end
    if toggle_button(imgui, 'Show MP Bar', config.ui.show_mp, function(value) mutate(model, function(candidate) candidate.ui.show_mp = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Show Status Text', config.ui.show_status, function(value) mutate(model, function(candidate) candidate.ui.show_status = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Show Remedy Button', config.ui.show_remedy_button, function(value) mutate(model, function(candidate) candidate.ui.show_remedy_button = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Show Alliance 2', config.ui.show_alliance_2, function(value) mutate(model, function(candidate) candidate.ui.show_alliance_2 = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Show Alliance 3', config.ui.show_alliance_3, function(value) mutate(model, function(candidate) candidate.ui.show_alliance_3 = value; end); end) then changed = true; end
    if toggle_button(imgui, 'Full Alliance Layout Preview', config.ui.full_alliance_preview, function(value) mutate(model, function(candidate) candidate.ui.full_alliance_preview = value; end); end) then changed = true; end
    if config.ui.full_alliance_preview then imgui.TextDisabled('Preview cards are display-only and cannot select targets or cast spells.'); end
    imgui.Separator();
    if stepper(imgui, 'Grid Columns', config.ui.grid_columns, 1, 6, 1, function(value) mutate(model, function(candidate) candidate.ui.grid_columns = value; end); window_initialized.main = false; end) then changed = true; end
    if stepper(imgui, 'Card Width', config.ui.card_width, 140, 360, 10, function(value) mutate(model, function(candidate) candidate.ui.card_width = value; end); window_initialized.main = false; end) then changed = true; end
    if stepper(imgui, 'Card Height', config.ui.card_height, 52, 120, 2, function(value) mutate(model, function(candidate) candidate.ui.card_height = value; end) end) then changed = true; end
    if stepper(imgui, 'Panel Opacity', config.ui.background_alpha * 100, 5, 90, 5, function(value) mutate(model, function(candidate) candidate.ui.background_alpha = value / 100; end); end) then changed = true; end
    imgui.TextDisabled('Lower opacity is more transparent.');
    if not config.ui.adaptive_scale then
        if stepper(imgui, 'Text Scale', config.ui.font_scale * 100, 60, 180, 5, function(value) mutate(model, function(candidate) candidate.ui.font_scale = value / 100; end); end) then changed = true; end
    end
    if stepper(imgui, 'Warning HP', config.thresholds.warning_hp, config.thresholds.critical_hp + 1, 100, 5, function(value) mutate(model, function(candidate) candidate.thresholds.warning_hp = value; end); end) then changed = true; end
    if stepper(imgui, 'Critical HP', config.thresholds.critical_hp, 0, config.thresholds.warning_hp - 1, 5, function(value) mutate(model, function(candidate) candidate.thresholds.critical_hp = value; end); end) then changed = true; end
    imgui.Separator();
    if imgui.Button('Reset Both Windows') then model:reset_layout(); AshitaShell.reset_window_positions(); changed = true; end
    imgui.TextDisabled('Drag a panel background to move it. Position saves automatically.');
    return changed;
end

local DIRECT_BINDINGS = {
    {key = 'left', label = 'Left Click'}, {key = 'right', label = 'Right Click'}, {key = 'middle', label = 'Middle Click'},
    {key = 'mouse4', label = 'Mouse 4 (side)'}, {key = 'mouse5', label = 'Mouse 5 (side)'},
    {key = 'wheel_up', label = 'Wheel Up (hover)'}, {key = 'wheel_down', label = 'Wheel Down (hover)'},
};

local function render_direct_tab(imgui, model, config)
    local changed = false;
    local armed = config.direct_click.enabled and config.live_test.manual_dispatch_enabled and not config.live_test.emergency_stop;
    imgui.Text('Direct Party-Frame Bindings');
    imgui.TextDisabled(armed and 'ACTIVE: each deliberate card input uses its configured spell.' or 'INACTIVE: card inputs select members only.');
    if toggle_button(imgui, 'Enable Direct Bindings', config.direct_click.enabled, function(value)
        mutate(model, function(candidate)
            candidate.direct_click.enabled = value;
            candidate.live_test.manual_dispatch_enabled = value;
            candidate.live_test.emergency_stop = not value;
        end);
    end) then changed = true; end
    for _, item in ipairs(DIRECT_BINDINGS) do
        local binding = config.direct_click[item.key];
        imgui.Separator(); imgui.Text(item.label);
        if edit_text(imgui, 'direct_spell_' .. item.key, 'Spell##direct_' .. item.key, binding.spell, function(value) mutate(model, function(candidate) candidate.direct_click[item.key].spell = value; end); end) then changed = true; end
        if toggle_button(imgui, 'Enable ' .. item.label, binding.enabled, function(value) mutate(model, function(candidate) candidate.direct_click[item.key].enabled = value; end); end) then changed = true; end
    end
    imgui.TextDisabled('Wheel bindings require the cursor to be directly over a party card and are limited to one action per scroll input.');
    return changed;
end

local REMEDY_GROUPS = {
    {title = 'Dedicated removal spells', keys = {'paralyze', 'doom', 'petrify', 'curse', 'plague', 'disease', 'silence', 'blind', 'poison'}},
    {title = 'Erase effects', keys = {'gravity', 'bind', 'slow', 'bio', 'dia', 'addle', 'flash', 'stun', 'elegy', 'requiem', 'helix'}},
    {title = 'Low-priority Erase groups', keys = {'elemental_dot', 'stat_down'}},
};

local function render_remedies_tab(imgui, model, config)
    local changed = false;
    imgui.Text('Debuff Remedy Rules');
    imgui.TextDisabled('Each Remedy click resolves one highest-priority recognized active debuff. Elemental dots and stat-down effects share their own Erase rules.');
    for _, group in ipairs(REMEDY_GROUPS) do
        imgui.Separator(); imgui.Text(group.title);
        for _, rule_key in ipairs(group.keys) do
            local rule = config.remedies[rule_key];
            if rule then
                imgui.Text(rule_key:upper() .. ' — priority ' .. tostring(rule.priority));
                if edit_text(imgui, 'remedy_spell_' .. rule_key, 'Spell##remedy_' .. rule_key, rule.spell, function(value) mutate(model, function(candidate) candidate.remedies[rule_key].spell = value; end); end) then changed = true; end
                if toggle_button(imgui, 'Enable ' .. rule_key, rule.enabled, function(value) mutate(model, function(candidate) candidate.remedies[rule_key].enabled = value; end); end) then changed = true; end
                if stepper(imgui, 'Priority ' .. rule_key, rule.priority, 0, 200, 5, function(value) mutate(model, function(candidate) candidate.remedies[rule_key].priority = value; end); end) then changed = true; end
            end
        end
    end
    return changed;
end

local function render_settings_window(imgui, model, callbacks)
    local changed = false;
    local view = model:view();
    local config = view.config;
    if not config.ui.settings_open then return false; end

    initialize_window(imgui, 'settings', config.ui.settings_x, config.ui.settings_y, 430, 0);
    local open = imgui.Begin('PartyCare Settings — By: Schmeee##grid');
    if open then
        changed = capture_position(model, 'capture_settings_position', imgui) or changed;
        view = model:view(); config = view.config;
        if imgui.Button('Save', {80, 0}) then save_settings(model, callbacks); end
        imgui.SameLine();
        if imgui.Button('Save & Close', {120, 0}) then save_settings(model, callbacks); close_settings(model); changed = true; end
        imgui.SameLine();
        if imgui.Button('Close', {80, 0}) then close_settings(model); changed = true; end
        if type(imgui.GetWindowWidth) == 'function' and type(imgui.SetCursorPosX) == 'function' then
            imgui.SetCursorPosX(math.max(0, imgui.GetWindowWidth() - 32));
        elseif type(imgui.SameLine) == 'function' then
            imgui.SameLine();
        end
        if imgui.Button('X##partycare_settings_top_close', {24, 0}) then close_settings(model); changed = true; end
        if settings_feedback then imgui.TextDisabled(settings_feedback); end
        imgui.Separator();
        if tab_button(imgui, 'general', 'General') then changed = true; end
        imgui.SameLine(); if tab_button(imgui, 'direct', 'Direct Click') then changed = true; end
        imgui.SameLine(); if tab_button(imgui, 'remedies', 'Remedies') then changed = true; end
        imgui.Separator();
        if settings_tab == 'general' then changed = render_general_tab(imgui, model, config) or changed;
        elseif settings_tab == 'direct' then changed = render_direct_tab(imgui, model, config) or changed;
        elseif settings_tab == 'remedies' then changed = render_remedies_tab(imgui, model, config) or changed;
        end
    end
    imgui.End();
    return changed;
end

local function grid_window_width(config, groups)
    local columns = 1;
    if not config.ui.xiui_style then
        for _, group in ipairs(groups or {}) do columns = math.max(columns, math.min(config.ui.grid_columns, #group.members)); end
    end
    return columns * config.ui.card_width + (columns - 1) * 8 + 20;
end

local function grid_layout_signature(config, groups)
    local counts = {};
    for _, group in ipairs(groups or {}) do table.insert(counts, tostring(#group.members)); end
    -- While adaptive scaling is enabled, card width changes continuously as the
    -- user drags the ImGui resize corner. Do not treat those live measurements
    -- as a layout change that reinitializes the window to its prior size.
    local width_signature = config.ui.adaptive_scale and 'live_resize' or tostring(config.ui.card_width);
    return table.concat({tostring(config.ui.full_alliance_preview), tostring(config.ui.xiui_style), tostring(config.ui.debuff_alert_mode), tostring(config.ui.grid_columns), width_signature, table.concat(counts, ',')}, '|');
end

local function preview_member(slot)
    local group = math.floor(slot / 6) + 1;
    local position = (slot % 6) + 1;
    local hp_percent = ({100, 92, 84, 76, 68, 60})[position];
    local mp_percent = ({100, 88, 76, 64, 52, 40})[position];
    return {
        id = 'layout_preview_' .. tostring(slot), party_slot = slot, alliance_group = group,
        name = string.format('Preview %d-%d', group, position),
        hp = hp_percent, hp_max = 100, hp_percent = hp_percent,
        mp = mp_percent, mp_max = 100, mp_percent = mp_percent,
        layout_preview = true, status = '', status_feed_available = true, status_icon_count = 0,
    };
end

local function full_alliance_preview_groups()
    local groups = {};
    for group = 1, 3 do
        local members = {};
        for position = 1, 6 do table.insert(members, preview_member((group - 1) * 6 + position - 1)); end
        table.insert(groups, {id = group, label = 'Preview Alliance ' .. tostring(group), members = members});
    end
    return groups;
end

local function visible_member_groups(members, config)
    if config.ui.full_alliance_preview then return full_alliance_preview_groups(); end
    local groups = {{id = 1, label = 'Party', members = {}}};
    if config.ui.show_alliance_2 then table.insert(groups, {id = 2, label = 'Alliance 2', members = {}}); end
    if config.ui.show_alliance_3 then table.insert(groups, {id = 3, label = 'Alliance 3', members = {}}); end
    local lookup = {};
    for _, group in ipairs(groups) do lookup[group.id] = group; end
    for _, member in ipairs(members) do
        local group = lookup[member.alliance_group or 1];
        if group and (not config.ui.debuff_alert_mode or member.remedy_recommendation ~= nil) then table.insert(group.members, member); end
    end
    local visible = {};
    for _, group in ipairs(groups) do if #group.members > 0 then table.insert(visible, group); end end
    return visible;
end

local function render_xiui_member_card(imgui, model, member, now, config)
    local card_width = config.ui.card_width;
    local group_open = begin_group(imgui);
    local pushed_count = 0;
    local button_color = rawget(_G, 'ImGuiCol_Button');
    local hover_color = rawget(_G, 'ImGuiCol_ButtonHovered');
    local active_color = rawget(_G, 'ImGuiCol_ButtonActive');
    if button_color and type(imgui.PushStyleColor) == 'function' and type(imgui.PopStyleColor) == 'function' then
        imgui.PushStyleColor(button_color, {0.12, 0.27, 0.39, 0.96}); pushed_count = pushed_count + 1;
        if hover_color then imgui.PushStyleColor(hover_color, {0.18, 0.39, 0.55, 0.98}); pushed_count = pushed_count + 1; end
        if active_color then imgui.PushStyleColor(active_color, {0.08, 0.20, 0.30, 1.00}); pushed_count = pushed_count + 1; end
    end
    member_click(imgui, model, member, now, card_width, 18, member.upkeep_alert_kind);
    if pushed_count > 0 then imgui.PopStyleColor(pushed_count); end

    local hp_color = ResourceStyle.hp_color(member.hp_percent / 100, config.thresholds.warning_hp, config.thresholds.critical_hp);
    styled_progress(imgui, member.hp_percent / 100, {card_width, ResourceStyle.bar_height(11, config.ui.font_scale)}, 'HP  ' .. tostring(member.hp_percent) .. '%', hp_color);
    if config.ui.show_mp and member.mp_max > 0 then
        local mp_color = ResourceStyle.mp_color(member.mp_percent / 100);
        styled_progress(imgui, member.mp_percent / 100, {card_width, ResourceStyle.bar_height(9, config.ui.font_scale)}, 'MP  ' .. tostring(member.mp_percent) .. '%', mp_color);
    end

    local recommendation = member.remedy_recommendation;
    if config.ui.show_remedy_button and recommendation then
        local remedy_label = 'Remedy: ' .. recommendation.spell .. ' (' .. recommendation.debuff .. ')##xiui_remedy_' .. tostring(member.id);
        if pulsing_remedy_button(imgui, remedy_label, {card_width, 15}, now) then
            model:select_member(member.id);
            model:request_remedy(now);
        end
        if type(imgui.IsItemHovered) == 'function' and imgui.IsItemHovered() and type(imgui.SetTooltip) == 'function' then
            imgui.SetTooltip('Priority ' .. tostring(recommendation.priority) .. ': ' .. recommendation.debuff .. ' → ' .. recommendation.spell);
        end
    elseif config.ui.show_status and type(member.detected_remedies) == 'table' and #member.detected_remedies > 0 then
        imgui.TextDisabled('Detected: ' .. table.concat(member.detected_remedies, ', '));
    elseif config.ui.show_status and not member.status_feed_available then
        imgui.TextDisabled('Status feed unavailable');
    elseif config.ui.show_status and member.status ~= '' then
        imgui.TextDisabled(member.status);
    else
        dummy(imgui, card_width, 13);
    end
    end_group(imgui, group_open);
end

local function render_debuff_alert(imgui, model, member, now, config)
    local card_width = config.ui.card_width;
    local group_open = begin_group(imgui);
    member_click(imgui, model, member, now, card_width, 18, false, true);
    local recommendation = member.remedy_recommendation;
    if recommendation then
        local label = 'Remedy: ' .. recommendation.spell .. ' (' .. recommendation.debuff .. ')##alert_remedy_' .. tostring(member.id);
        if pulsing_remedy_button(imgui, label, {card_width, 16}, now) then
            model:select_member(member.id);
            model:request_remedy(now);
        end
        if type(imgui.IsItemHovered) == 'function' and imgui.IsItemHovered() and type(imgui.SetTooltip) == 'function' then
            imgui.SetTooltip('Priority ' .. tostring(recommendation.priority) .. ': ' .. recommendation.debuff .. ' → ' .. recommendation.spell);
        end
    end
    end_group(imgui, group_open);
end

local function render_member_card(imgui, model, member, now, config)
    if config.ui.debuff_alert_mode and not member.layout_preview then return render_debuff_alert(imgui, model, member, now, config); end
    if config.ui.xiui_style then return render_xiui_member_card(imgui, model, member, now, config); end
    local card_width = config.ui.card_width;
    local group_open = begin_group(imgui);
    local clicked = member_click(imgui, model, member, now, card_width, config.ui.member_height, member.upkeep_alert_kind);
    local latest = model:view();
    if clicked then latest = model:view(); end
    local hp_color = ResourceStyle.hp_color(member.hp_percent / 100, config.thresholds.warning_hp, config.thresholds.critical_hp);
    local hp_bar_h = ResourceStyle.bar_height(12, config.ui.font_scale);
    styled_progress(imgui, member.hp_percent / 100, {card_width, hp_bar_h}, ResourceStyle.bar_label('HP', member.hp, member.hp_max), hp_color);
    if config.ui.show_mp and member.mp_max > 0 then
        local mp_color = ResourceStyle.mp_color(member.mp_percent / 100);
        local mp_bar_h = ResourceStyle.bar_height(10, config.ui.font_scale);
        styled_progress(imgui, member.mp_percent / 100, {card_width, mp_bar_h}, ResourceStyle.bar_label('MP', member.mp, member.mp_max), mp_color);
    end
    local recommendation = member.remedy_recommendation;
    if config.ui.show_remedy_button and recommendation then
        local remedy_label = 'Remedy: ' .. recommendation.spell .. ' (' .. recommendation.debuff .. ')##remedy_' .. tostring(member.id);
        if pulsing_remedy_button(imgui, remedy_label, {card_width, 16}, now) then
            model:select_member(member.id);
            model:request_remedy(now);
        end
        if type(imgui.IsItemHovered) == 'function' and imgui.IsItemHovered() and type(imgui.SetTooltip) == 'function' then
            imgui.SetTooltip('Priority ' .. tostring(recommendation.priority) .. ': ' .. recommendation.debuff .. ' → ' .. recommendation.spell);
        end
    elseif config.ui.show_status and type(member.detected_remedies) == 'table' and #member.detected_remedies > 0 then
        imgui.TextDisabled('Detected: ' .. table.concat(member.detected_remedies, ', '));
    elseif config.ui.show_status and not member.status_feed_available then
        imgui.TextDisabled('Status feed unavailable');
    elseif config.ui.show_status and member.status ~= '' then
        imgui.TextDisabled(member.status);
    else
        dummy(imgui, card_width, 16);
    end
    end_group(imgui, group_open);
end

local function render_enemy_dispel_alert(imgui, model, now, config, enemy)
    if config.ui.enemy_dispel_alert_mode ~= true then return false; end
    local actionable = type(enemy) == 'table' and enemy.action_available == true;
    if not actionable and config.ui.enemy_dispel_alert_preview ~= true then return false; end

    local changed = false;
    local alpha = math.min(config.ui.background_alpha, 0.20);
    set_window_alpha(imgui, alpha);
    local background_pushed = push_window_background(imgui, alpha);
    initialize_window(imgui, 'enemy', config.ui.enemy_dispel_x, config.ui.enemy_dispel_y, config.ui.card_width, 40);
    local open = imgui.Begin('Enemy Dispel##partycare_enemy_dispel', true, _G.ImGuiWindowFlags_NoTitleBar);
    if open then
        if not config.ui.locked then changed = capture_position(model, 'capture_enemy_window_position', imgui) or changed; end
        if actionable then
            local detail = enemy.detected_effect and (' (' .. enemy.detected_effect .. ')') or '';
            local label = 'Dispel: ' .. enemy.name .. detail .. '##enemy_dispel_' .. tostring(enemy.id);
            if pulsing_remedy_button(imgui, label, {config.ui.card_width, 20}, now) then
                model:request_enemy_dispel(now);
            end
            if type(imgui.IsItemHovered) == 'function' and imgui.IsItemHovered() and type(imgui.SetTooltip) == 'function' then
                imgui.SetTooltip('Select this enemy, then click for a manual Dispel. PartyCare never retargets or casts automatically.');
            end
        else
            -- Placement preview is deliberately content-free while idle.
            dummy(imgui, config.ui.card_width, 18);
        end
    end
    imgui.End();
    if background_pushed then imgui.PopStyleColor(1); end
    return changed;
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

    local groups = visible_member_groups(view.members, config);
    local compact_idle = config.ui.debuff_alert_mode and #groups == 0;
    if compact_idle and not config.ui.debuff_alert_preview then
        -- Party compact mode stays hidden, but the independent enemy compact
        -- panel can still appear for a log-confirmed battle enemy.
        local enemy_changed = render_enemy_dispel_alert(imgui, model, now, config, view.enemy) or false;
        local settings_changed = render_settings_window(imgui, model, callbacks) or false;
        return model:drain_audit(), nil, enemy_changed or settings_changed;
    end
    local layout_signature = grid_layout_signature(config, groups);
    if main_layout_signature ~= layout_signature then
        main_layout_signature = layout_signature;
        window_initialized.main = false;
    end
    local effective_alpha = config.ui.xiui_style and math.min(config.ui.background_alpha, 0.10) or config.ui.background_alpha;
    set_window_alpha(imgui, effective_alpha);
    local background_pushed = push_window_background(imgui, effective_alpha);
    initialize_window(imgui, 'main', config.ui.x, config.ui.y, grid_window_width(config, groups), config.ui.height);
    local titlebar_flag = (config.ui.minimal_mode or config.ui.debuff_alert_mode) and _G.ImGuiWindowFlags_NoTitleBar or nil;
    local open;
    if titlebar_flag then open = imgui.Begin('PartyCare##grid', true, titlebar_flag); else open = imgui.Begin('PartyCare##grid'); end
    if open then
        if not config.ui.locked then changed = capture_position(model, 'capture_window_position', imgui) or changed; end
        changed = capture_size(model, imgui) or changed;
        view = model:view(); config = view.config;
        set_font_scale(imgui, config.ui.font_scale);
        if not config.ui.minimal_mode and not config.ui.debuff_alert_mode then
            if imgui.Button(config.ui.settings_open and 'Close Settings' or 'Settings', {-1, 0}) then
                mutate(model, function(candidate) candidate.ui.settings_open = not candidate.ui.settings_open; end);
                if not config.ui.settings_open then settings_tab = 'general'; end
                changed = true;
            end
            local armed = config.direct_click.enabled and config.live_test.manual_dispatch_enabled and not config.live_test.emergency_stop;
            imgui.TextDisabled(armed and 'DIRECT CLICK: ACTIVE' or 'DIRECT CLICK: OFF');
            imgui.Separator();
        end

        groups = visible_member_groups(view.members, config);
        if config.ui.debuff_alert_mode and #groups == 0 then
            -- Preview remains content-free: it exists solely to reposition the hidden alert panel.
            dummy(imgui, math.max(20, config.ui.card_width), 18);
        end
        for group_index, group in ipairs(groups) do
            if #groups > 1 then
                if group_index > 1 then imgui.Separator(); end
                imgui.TextDisabled(group.label);
            end
            for index, member in ipairs(group.members) do
                render_member_card(imgui, model, member, now, config);
                if not config.ui.xiui_style and index % config.ui.grid_columns ~= 0 and index < #group.members then imgui.SameLine(); end
            end
        end
        if not config.ui.minimal_mode and not config.ui.debuff_alert_mode then imgui.TextDisabled('By: Schmeee'); end

    end
    imgui.End();
    if background_pushed then imgui.PopStyleColor(1); end
    view = model:view(); config = view.config;
    changed = render_enemy_dispel_alert(imgui, model, now, config, view.enemy) or changed;
    changed = render_settings_window(imgui, model, callbacks) or changed;
    return model:drain_audit(), nil, changed;
end

return AshitaShell;
