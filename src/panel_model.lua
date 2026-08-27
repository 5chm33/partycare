local Config = require('src.config');
local Party = require('src.party');
local Intents = require('src.intents');
local Util = require('src.util');
local Remedies = require('src.remedies');

local PanelModel = {};
PanelModel.__index = PanelModel;

local function apply_refresh_continuity(members, previous_refresh, now, ui)
    local next_refresh = {};
    now = tonumber(now) or 0;
    for _, member in ipairs(members or {}) do
        local key = tostring(member.id);
        local prior = previous_refresh and previous_refresh[key] or nil;
        if member.refresh_known == true then
            if member.has_refresh == true then
                local applied_at = prior and prior.has_refresh == true and prior.applied_at or now;
                local duration = ui and ui.refresh_duration_seconds or 150;
                local lead = ui and ui.refresh_early_seconds or 15;
                member.refresh_early = ui and ui.refresh_early_pulse_enabled == true
                    and now >= (applied_at + duration - lead);
                next_refresh[key] = {has_refresh = true, applied_at = applied_at};
            else
                next_refresh[key] = {has_refresh = false};
            end
        elseif prior and prior.has_refresh == false then
            -- A transient unavailable feed must not clear an existing missing-
            -- Refresh alert. It remains active until a later readable source
            -- positively confirms the buff is present.
            member.refresh_known = true;
            member.has_refresh = false;
            member.refresh_source = 'retained_missing_refresh';
            next_refresh[key] = prior;
        elseif prior and prior.has_refresh == true then
            -- Keep the observed Refresh timer through a brief unavailable-feed
            -- interval. A later readable absent state still overrides it.
            member.refresh_known = true;
            member.has_refresh = true;
            local duration = ui and ui.refresh_duration_seconds or 150;
            local lead = ui and ui.refresh_early_seconds or 15;
            member.refresh_early = ui and ui.refresh_early_pulse_enabled == true
                and now >= ((prior.applied_at or now) + duration - lead);
            next_refresh[key] = prior;
        end
    end
    return next_refresh;
end

local function apply_haste_continuity(members, previous_haste, now, ui)
    local next_haste = {};
    now = tonumber(now) or 0;
    for _, member in ipairs(members or {}) do
        local key = tostring(member.id);
        local prior = previous_haste and previous_haste[key] or nil;
        if member.haste_known == true then
            if member.has_haste == true then
                local applied_at = prior and prior.has_haste == true and prior.applied_at or now;
                local duration = ui and ui.haste_duration_seconds or 180;
                local lead = ui and ui.haste_early_seconds or 15;
                member.haste_early = ui and ui.haste_early_pulse_enabled == true
                    and now >= (applied_at + duration - lead);
                next_haste[key] = {has_haste = true, applied_at = applied_at};
            else
                next_haste[key] = {has_haste = false};
            end
        elseif prior and prior.has_haste == false then
            -- Preserve a confirmed missing Haste state through a short source
            -- gap, just as Refresh does, until a readable active state clears it.
            member.haste_known = true;
            member.has_haste = false;
            member.haste_source = 'retained_missing_haste';
            next_haste[key] = prior;
        elseif prior and prior.has_haste == true then
            member.haste_known = true;
            member.has_haste = true;
            local duration = ui and ui.haste_duration_seconds or 180;
            local lead = ui and ui.haste_early_seconds or 15;
            member.haste_early = ui and ui.haste_early_pulse_enabled == true
                and now >= ((prior.applied_at or now) + duration - lead);
            next_haste[key] = prior;
        end
    end
    return next_haste;
end

local function decorate_members(members, config)
    local decorated = Party.decorate_members(members, config.thresholds, config.ui);
    for _, member in ipairs(decorated) do
        local recommendation, candidates = Remedies.recommend(member, config.remedies, member.spell_availability);
        member.remedy_recommendation = recommendation;
        member.remedy_candidates = candidates;
        member.detected_remedies = Remedies.normalize_list(member);
    end
    return decorated;
end

function PanelModel.new(raw_config)
    local config, errors = Config.validate(raw_config or Config.DEFAULT);
    if not config then return nil, errors; end

    local self = setmetatable({}, PanelModel);
    self.config = config;
    self.members = {};
    self.enemy = nil;
    self.refresh_by_member_id = {};
    self.haste_by_member_id = {};
    self.intent_state = Intents.new();
    self.revision = 0;
    return self, {};
end

function PanelModel:replace_config(raw_config)
    local config, errors = Config.validate(raw_config);
    if not config then return false, errors; end
    self.config = config;
    self.revision = self.revision + 1;
    return true, {};
end

function PanelModel:export_config()
    return Util.copy(self.config);
end

function PanelModel:update_config(mutator)
    if type(mutator) ~= 'function' then return false, {'configuration mutator must be a function'}; end
    local candidate = Util.copy(self.config);
    mutator(candidate);
    local updated, errors = self:replace_config(candidate);
    if not updated then return false, errors; end
    self.members = decorate_members(self.members, self.config);
    return true, {};
end

function PanelModel:set_ui_value(key, value)
    return self:update_config(function(candidate)
        candidate.ui[key] = value;
    end);
end

function PanelModel:capture_window_position(x, y)
    if not Util.is_finite_number(x) or not Util.is_finite_number(y) then return false, {'window position must be finite'}; end
    if self.config.ui.locked then return false, {}; end
    if math.abs(self.config.ui.x - x) < 1 and math.abs(self.config.ui.y - y) < 1 then
        return false, {};
    end
    return self:update_config(function(candidate)
        candidate.ui.x = x;
        candidate.ui.y = y;
    end);
end

function PanelModel:capture_enemy_window_position(x, y)
    if not Util.is_finite_number(x) or not Util.is_finite_number(y) then return false, {'enemy window position must be finite'}; end
    if self.config.ui.locked then return false, {}; end
    if math.abs(self.config.ui.enemy_dispel_x - x) < 1 and math.abs(self.config.ui.enemy_dispel_y - y) < 1 then
        return false, {};
    end
    return self:update_config(function(candidate)
        candidate.ui.enemy_dispel_x = x;
        candidate.ui.enemy_dispel_y = y;
    end);
end

function PanelModel:capture_window_size(width, height)
    if not Util.is_finite_number(width) or not Util.is_finite_number(height) then return false, {'window size must be finite'}; end
    if self.config.ui.adaptive_scale ~= true then return false, {}; end
    local columns = self.config.ui.grid_columns;
    local card_width = math.max(140, math.min(360, math.floor((width - 20 - (columns - 1) * 8) / columns)));
    local card_height = math.max(52, math.min(120, math.floor(card_width * 0.37)));
    local font_scale = math.max(0.60, math.min(1.80, card_width / 200));
    if math.abs(self.config.ui.card_width - card_width) < 2 and math.abs(self.config.ui.card_height - card_height) < 2 and math.abs(self.config.ui.font_scale - font_scale) < 0.02 then return false, {}; end
    return self:update_config(function(candidate)
        candidate.ui.card_width = card_width;
        candidate.ui.card_height = card_height;
        candidate.ui.font_scale = font_scale;
    end);
end

function PanelModel:capture_settings_position(x, y)
    if not Util.is_finite_number(x) or not Util.is_finite_number(y) then return false, {'settings position must be finite'}; end
    if math.abs(self.config.ui.settings_x - x) < 1 and math.abs(self.config.ui.settings_y - y) < 1 then
        return false, {};
    end
    return self:update_config(function(candidate)
        candidate.ui.settings_x = x;
        candidate.ui.settings_y = y;
    end);
end

function PanelModel:reset_layout()
    return self:update_config(function(candidate)
        candidate.ui.x = Config.DEFAULT.ui.x;
        candidate.ui.y = Config.DEFAULT.ui.y;
        candidate.ui.settings_x = Config.DEFAULT.ui.settings_x;
        candidate.ui.settings_y = Config.DEFAULT.ui.settings_y;
        candidate.ui.width = Config.DEFAULT.ui.width;
        candidate.ui.height = Config.DEFAULT.ui.height;
        candidate.ui.member_height = Config.DEFAULT.ui.member_height;
        candidate.ui.layout = Config.DEFAULT.ui.layout;
        candidate.ui.grid_columns = Config.DEFAULT.ui.grid_columns;
        candidate.ui.card_width = Config.DEFAULT.ui.card_width;
        candidate.ui.card_height = Config.DEFAULT.ui.card_height;
        candidate.ui.background_alpha = Config.DEFAULT.ui.background_alpha;
        candidate.ui.minimal_mode = Config.DEFAULT.ui.minimal_mode;
        candidate.ui.adaptive_scale = Config.DEFAULT.ui.adaptive_scale;
        candidate.ui.font_scale = Config.DEFAULT.ui.font_scale;
        candidate.ui.xiui_style = Config.DEFAULT.ui.xiui_style;
        candidate.ui.debuff_alert_mode = Config.DEFAULT.ui.debuff_alert_mode;
        candidate.ui.debuff_alert_preview = Config.DEFAULT.ui.debuff_alert_preview;
        candidate.ui.enemy_dispel_alert_mode = Config.DEFAULT.ui.enemy_dispel_alert_mode;
        candidate.ui.enemy_dispel_alert_preview = Config.DEFAULT.ui.enemy_dispel_alert_preview;
        candidate.ui.enemy_dispel_x = Config.DEFAULT.ui.enemy_dispel_x;
        candidate.ui.enemy_dispel_y = Config.DEFAULT.ui.enemy_dispel_y;
        candidate.ui.refresh_pulse_enabled = Config.DEFAULT.ui.refresh_pulse_enabled;
        candidate.ui.refresh_min_mp = Config.DEFAULT.ui.refresh_min_mp;
        candidate.ui.refresh_early_pulse_enabled = Config.DEFAULT.ui.refresh_early_pulse_enabled;
        candidate.ui.refresh_duration_seconds = Config.DEFAULT.ui.refresh_duration_seconds;
        candidate.ui.refresh_early_seconds = Config.DEFAULT.ui.refresh_early_seconds;
        candidate.ui.haste_pulse_enabled = Config.DEFAULT.ui.haste_pulse_enabled;
        candidate.ui.haste_early_pulse_enabled = Config.DEFAULT.ui.haste_early_pulse_enabled;
        candidate.ui.haste_duration_seconds = Config.DEFAULT.ui.haste_duration_seconds;
        candidate.ui.haste_early_seconds = Config.DEFAULT.ui.haste_early_seconds;
        candidate.ui.show_action_bar = Config.DEFAULT.ui.show_action_bar;
        candidate.ui.show_remedy_button = Config.DEFAULT.ui.show_remedy_button;
    end);
end

function PanelModel:update_members(raw_members, now)
    local members, errors = Party.normalize_members(raw_members);
    if not members then return false, errors; end
    self.refresh_by_member_id = apply_refresh_continuity(members, self.refresh_by_member_id, now, self.config.ui);
    self.haste_by_member_id = apply_haste_continuity(members, self.haste_by_member_id, now, self.config.ui);
    self.members = decorate_members(members, self.config);
    if self.intent_state.selected_member_id ~= nil and not Party.find_member(self.members, self.intent_state.selected_member_id) then
        Intents.clear_selection(self.intent_state);
    end
    self.revision = self.revision + 1;
    return true, {};
end

function PanelModel:mark_refresh_reapplied(member_id, now)
    if member_id == nil then return false, 'member id is required'; end
    now = tonumber(now) or 0;
    local key = tostring(member_id);
    self.refresh_by_member_id[key] = {has_refresh = true, applied_at = now};
    for _, member in ipairs(self.members or {}) do
        if tostring(member.id) == key then
            member.refresh_known = true;
            member.has_refresh = true;
            member.refresh_early = false;
            member.refresh_source = 'observed_refresh_cast';
        end
    end
    self.members = decorate_members(self.members, self.config);
    self.revision = self.revision + 1;
    return true, nil;
end

function PanelModel:mark_haste_reapplied(member_id, now)
    if member_id == nil then return false, 'member id is required'; end
    now = tonumber(now) or 0;
    local key = tostring(member_id);
    self.haste_by_member_id[key] = {has_haste = true, applied_at = now};
    for _, member in ipairs(self.members or {}) do
        if tostring(member.id) == key then
            member.haste_known = true;
            member.has_haste = true;
            member.haste_early = false;
            member.haste_source = 'observed_haste_cast';
        end
    end
    self.members = decorate_members(self.members, self.config);
    self.revision = self.revision + 1;
    return true, nil;
end

function PanelModel:update_enemy(enemy)
    if enemy == nil then
        self.enemy = nil;
        self.revision = self.revision + 1;
        return true, {};
    end
    if type(enemy) ~= 'table' or enemy.id == nil or not Util.is_nonempty_string(enemy.name) then
        return false, {'enemy must contain an id and name'};
    end
    self.enemy = Util.copy(enemy);
    self.revision = self.revision + 1;
    return true, {};
end

function PanelModel:selected_member()
    if self.intent_state.selected_member_id == nil then return nil; end
    return Party.find_member(self.members, self.intent_state.selected_member_id);
end

function PanelModel:select_member(member_id)
    local member = Party.find_member(self.members, member_id);
    if not member then return false, 'member is not present in current panel state'; end
    return Intents.select(self.intent_state, member);
end

function PanelModel:request_direct_click(member_id, button, now)
    if self.config.direct_click.enabled ~= true then return nil, 'direct click mode is disabled'; end
    local binding = self.config.direct_click[button];
    if type(binding) ~= 'table' or binding.enabled ~= true then return nil, 'direct click binding is disabled or unknown'; end
    local member = Party.find_member(self.members, member_id);
    if not member then return nil, 'clicked member is not present in current panel state'; end
    Intents.select(self.intent_state, member);
    local action = {label = 'Direct ' .. button .. ': ' .. binding.spell, spell = binding.spell, enabled = true};
    local intent, error_message = Intents.request(self.intent_state, 'direct_' .. button, action, member, now, self.config.review.review_click_cast_enabled);
    if intent then
        intent.direct_click = true;
        intent.mouse_button = button;
        local recorded = self.intent_state.audit[#self.intent_state.audit];
        if type(recorded) == 'table' then recorded.direct_click = true; recorded.mouse_button = button; end
    end
    return intent, error_message;
end

function PanelModel:request_action(action_key, now)
    local action = self.config.actions[action_key];
    if type(action) ~= 'table' or not action.enabled then return nil, 'action is disabled or unknown'; end
    local member = self:selected_member();
    if not member then return nil, 'select a party member before choosing an action'; end
    return Intents.request(self.intent_state, action_key, action, member, now, self.config.review.review_click_cast_enabled);
end

function PanelModel:request_remedy(now)
    local member = self:selected_member();
    if not member then return nil, 'select a party member before choosing a remedy'; end
    local recommendation = member.remedy_recommendation;
    if type(recommendation) ~= 'table' then return nil, 'selected member has no configured removable debuff'; end
    local action = {label = 'Remedy: ' .. recommendation.debuff, spell = recommendation.spell, enabled = true};
    local intent, error_message = Intents.request(self.intent_state, 'remedy', action, member, now, self.config.review.review_click_cast_enabled);
    if intent then
        intent.remedy_rule_id = recommendation.rule_id;
        intent.remedy_debuff = recommendation.debuff;
        intent.remedy_priority = recommendation.priority;
    end
    return intent, error_message;
end

function PanelModel:request_enemy_dispel(now)
    if self.config.ui.enemy_dispel_alert_mode ~= true then return nil, 'enemy Dispel alert mode is disabled'; end
    local enemy = self.enemy;
    if type(enemy) ~= 'table' or enemy.action_available ~= true then return nil, 'no actionable enemy target'; end
    local action = {label = 'Dispel', spell = enemy.spell or 'Dispel', enabled = true};
    return Intents.request_current_target(self.intent_state, 'enemy_dispel', action, enemy, now, self.config.review.review_click_cast_enabled);
end

function PanelModel:view()
    return {
        revision = self.revision,
        config = Util.copy(self.config),
        members = Util.copy(self.members),
        enemy = Util.copy(self.enemy),
        selected_member_id = self.intent_state.selected_member_id,
    };
end

function PanelModel:drain_audit()
    return Intents.drain_audit(self.intent_state);
end

return PanelModel;
