local Config = require('src.config');
local Party = require('src.party');
local Intents = require('src.intents');
local Util = require('src.util');
local Remedies = require('src.remedies');

local PanelModel = {};
PanelModel.__index = PanelModel;

local function decorate_members(members, config)
    local decorated = Party.decorate_members(members, config.thresholds);
    for _, member in ipairs(decorated) do
        local recommendation, candidates = Remedies.recommend(member, config.remedies);
        member.remedy_recommendation = recommendation;
        member.remedy_candidates = candidates;
    end
    return decorated;
end

function PanelModel.new(raw_config)
    local config, errors = Config.validate(raw_config or Config.DEFAULT);
    if not config then return nil, errors; end

    local self = setmetatable({}, PanelModel);
    self.config = config;
    self.members = {};
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
        candidate.ui.show_action_bar = Config.DEFAULT.ui.show_action_bar;
        candidate.ui.show_remedy_button = Config.DEFAULT.ui.show_remedy_button;
    end);
end

function PanelModel:update_members(raw_members)
    local members, errors = Party.normalize_members(raw_members);
    if not members then return false, errors; end
    self.members = decorate_members(members, self.config);
    if self.intent_state.selected_member_id ~= nil and not Party.find_member(self.members, self.intent_state.selected_member_id) then
        Intents.clear_selection(self.intent_state);
    end
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

function PanelModel:view()
    return {
        revision = self.revision,
        config = Util.copy(self.config),
        members = Util.copy(self.members),
        selected_member_id = self.intent_state.selected_member_id,
    };
end

function PanelModel:drain_audit()
    return Intents.drain_audit(self.intent_state);
end

return PanelModel;
