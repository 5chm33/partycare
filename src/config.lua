local Util = require('src.util');

local Config = {};
Config.VERSION = 12;

Config.DEFAULT = {
    version = Config.VERSION,
    ui = {
        visible = true, locked = false, settings_open = false,
        x = 24, y = 180, settings_x = 360, settings_y = 180,
        width = 420, height = 0, member_height = 24,
        layout = 'grid', grid_columns = 2, card_width = 200, card_height = 74,
        background_alpha = 0.52,
        minimal_mode = true, adaptive_scale = true, font_scale = 1.00,
        show_mp = true, show_status = true, show_action_bar = false, show_remedy_button = true,
        show_alliance_2 = false, show_alliance_3 = false,
    },
    thresholds = {warning_hp = 55, critical_hp = 30},
    actions = {
        primary = {label = 'Cure IV', spell = 'Cure IV', enabled = true},
        secondary = {label = 'Regen', spell = 'Regen', enabled = true},
        emergency = {label = 'Cure V', spell = 'Cure V', enabled = true},
        refresh = {label = 'Refresh', spell = 'Refresh', enabled = false},
    },
    remedies = {
        paralyze = {spell = 'Paralyna', enabled = true, priority = 100},
        gravity = {spell = 'Erase', enabled = true, priority = 90},
        slow = {spell = 'Erase', enabled = true, priority = 85},
        silence = {spell = 'Silena', enabled = true, priority = 70},
        blind = {spell = 'Blindna', enabled = true, priority = 60},
        poison = {spell = 'Poisona', enabled = true, priority = 50},
        bio = {spell = 'Erase', enabled = true, priority = 45},
        dia = {spell = 'Erase', enabled = true, priority = 45},
    },
    review = {review_click_cast_enabled = false, approval_status = 'PENDING_HORIZONXI_REVIEW'},
    live_test = {manual_dispatch_enabled = true, emergency_stop = false},
    direct_click = {
        enabled = true,
        left = {spell = 'Cure IV', enabled = true},
        right = {spell = 'Regen', enabled = false},
        middle = {spell = 'Cure V', enabled = false},
    },
    colors = {
        healthy = {0.15, 0.70, 0.35, 1.00}, warning = {0.92, 0.63, 0.12, 1.00},
        critical = {0.86, 0.22, 0.22, 1.00}, inactive = {0.32, 0.34, 0.38, 1.00},
    },
};

local ROOT_FIELDS = {version = true, ui = true, thresholds = true, actions = true, remedies = true, review = true, live_test = true, direct_click = true, colors = true};
local UI_FIELDS = {
    visible = true, locked = true, settings_open = true, x = true, y = true, settings_x = true, settings_y = true,
    width = true, height = true, member_height = true, layout = true, grid_columns = true, card_width = true, card_height = true,
    background_alpha = true, minimal_mode = true, adaptive_scale = true, font_scale = true,
    show_mp = true, show_status = true, show_action_bar = true, show_remedy_button = true,
    show_alliance_2 = true, show_alliance_3 = true,
};
local THRESHOLD_FIELDS = {warning_hp = true, critical_hp = true};
local ACTION_FIELDS = {label = true, spell = true, enabled = true};
local ACTION_KEYS = {primary = true, secondary = true, emergency = true, refresh = true};
local REMEDY_FIELDS = {spell = true, enabled = true, priority = true};
local REVIEW_FIELDS = {review_click_cast_enabled = true, approval_status = true};
local LIVE_TEST_FIELDS = {manual_dispatch_enabled = true, emergency_stop = true};
local DIRECT_CLICK_FIELDS = {enabled = true, left = true, right = true, middle = true};
local DIRECT_CLICK_BINDING_FIELDS = {spell = true, enabled = true};
local COLOR_KEYS = {healthy = true, warning = true, critical = true, inactive = true};

local function unknown_fields(value, allowed, context, errors)
    for key in pairs(value or {}) do
        if not allowed[key] then table.insert(errors, context .. ' has unsupported field: ' .. tostring(key)); end
    end
end

local function migrate(raw)
    if type(raw) ~= 'table' then return raw; end
    if raw.version and raw.version < Config.VERSION then
        raw = Util.copy(raw);
        local previous_version = raw.version;
        raw.version = Config.VERSION;
        raw.ui, raw.actions, raw.remedies, raw.review, raw.live_test, raw.direct_click = raw.ui or {}, raw.actions or {}, raw.remedies or {}, raw.review or {}, raw.live_test or {}, raw.direct_click or {};
        for _, key in ipairs({'height', 'settings_open', 'settings_x', 'settings_y', 'layout', 'grid_columns', 'card_width', 'card_height', 'background_alpha', 'minimal_mode', 'adaptive_scale', 'font_scale', 'show_remedy_button', 'show_alliance_2', 'show_alliance_3'}) do
            if raw.ui[key] == nil then raw.ui[key] = Config.DEFAULT.ui[key]; end
        end
        for key, default_action in pairs(Config.DEFAULT.actions) do
            raw.actions[key] = raw.actions[key] or {};
            if raw.actions[key].spell == nil then raw.actions[key].spell = default_action.spell; end
        end
        for key, default_rule in pairs(Config.DEFAULT.remedies) do raw.remedies[key] = raw.remedies[key] or Util.copy(default_rule); end
        if raw.review.review_click_cast_enabled == nil then raw.review.review_click_cast_enabled = false; end
        if raw.review.approval_status == nil then raw.review.approval_status = Config.DEFAULT.review.approval_status; end
        if raw.live_test.manual_dispatch_enabled == nil then raw.live_test.manual_dispatch_enabled = true; end
        if raw.live_test.emergency_stop == nil then raw.live_test.emergency_stop = false; end
        if raw.direct_click.enabled == nil then raw.direct_click.enabled = true; end
        if previous_version < 9 then
            raw.direct_click.enabled = true;
            raw.live_test.manual_dispatch_enabled = true;
            raw.live_test.emergency_stop = false;
        end
        if previous_version < 10 then
            raw.ui.layout = 'grid';
            raw.ui.grid_columns = 2;
            raw.ui.card_width = 200;
            raw.ui.card_height = 74;
            raw.ui.background_alpha = 0.52;
            raw.ui.show_action_bar = false;
            raw.ui.show_remedy_button = true;
            raw.ui.width = 420;
            raw.ui.member_height = 24;
        end
        if previous_version < 11 then
            raw.ui.minimal_mode = true;
            raw.ui.adaptive_scale = true;
            raw.ui.font_scale = 1.00;
        end
        if previous_version < 12 then
            raw.ui.show_alliance_2 = false;
            raw.ui.show_alliance_3 = false;
        end
        for key, default_binding in pairs(Config.DEFAULT.direct_click) do
            if key ~= 'enabled' then raw.direct_click[key] = raw.direct_click[key] or Util.copy(default_binding); end
        end
    end
    return raw;
end

local function normalize_color(value, label, errors)
    if type(value) ~= 'table' or #value ~= 4 then table.insert(errors, label .. ' must be a four-channel color'); return nil; end
    local normalized = {};
    for index = 1, 4 do
        if not Util.is_finite_number(value[index]) or value[index] < 0 or value[index] > 1 then
            table.insert(errors, label .. ' channel ' .. index .. ' must be between 0 and 1'); return nil;
        end
        normalized[index] = value[index];
    end
    return normalized;
end

local function validate_binding(value, label, fields, result, errors, require_label)
    if type(value) ~= 'table' then table.insert(errors, label .. ' must be a table'); return; end
    unknown_fields(value, fields, label, errors);
    if require_label and not Util.is_nonempty_string(value.label) then table.insert(errors, label .. '.label is required'); end
    if not Util.is_nonempty_string(value.spell) then table.insert(errors, label .. '.spell is required'); end
    if type(value.enabled) ~= 'boolean' then table.insert(errors, label .. '.enabled must be boolean'); end
    if fields.priority and (not Util.is_integer(value.priority) or value.priority < 0 or value.priority > 1000) then table.insert(errors, label .. '.priority must be an integer from 0 to 1000'); end
    if Util.is_nonempty_string(value.spell) and type(value.enabled) == 'boolean' and (not fields.priority or (Util.is_integer(value.priority) and value.priority >= 0 and value.priority <= 1000)) then
        result.spell, result.enabled = value.spell, value.enabled;
        if require_label then result.label = value.label; end
        if fields.priority then result.priority = value.priority; end
    end
end

function Config.validate(raw)
    raw = migrate(raw);
    if type(raw) ~= 'table' then return nil, {'configuration must be a table'}; end
    if raw.version ~= Config.VERSION then return nil, {'unsupported configuration version'}; end

    local errors, result = {}, Util.copy(Config.DEFAULT);
    unknown_fields(raw, ROOT_FIELDS, 'configuration', errors);
    if type(raw.ui) ~= 'table' then table.insert(errors, 'ui must be a table'); else
        unknown_fields(raw.ui, UI_FIELDS, 'ui', errors);
        for _, key in ipairs({'visible', 'locked', 'settings_open', 'minimal_mode', 'adaptive_scale', 'show_mp', 'show_status', 'show_action_bar', 'show_remedy_button', 'show_alliance_2', 'show_alliance_3'}) do
            if type(raw.ui[key]) == 'boolean' then result.ui[key] = raw.ui[key] else table.insert(errors, 'ui.' .. key .. ' must be boolean'); end
        end
        for _, key in ipairs({'x', 'y', 'settings_x', 'settings_y'}) do
            if Util.is_finite_number(raw.ui[key]) then result.ui[key] = raw.ui[key] else table.insert(errors, 'ui.' .. key .. ' must be finite'); end
        end
        for _, key in ipairs({'width', 'member_height', 'card_width', 'card_height'}) do
            if Util.is_finite_number(raw.ui[key]) and raw.ui[key] >= 20 then result.ui[key] = raw.ui[key] else table.insert(errors, 'ui.' .. key .. ' must be at least 20'); end
        end
        if Util.is_finite_number(raw.ui.height) and raw.ui.height >= 0 then result.ui.height = raw.ui.height else table.insert(errors, 'ui.height must be non-negative'); end
        if raw.ui.layout ~= 'grid' then table.insert(errors, 'ui.layout must be grid'); else result.ui.layout = raw.ui.layout; end
        if not Util.is_integer(raw.ui.grid_columns) or raw.ui.grid_columns < 1 or raw.ui.grid_columns > 3 then table.insert(errors, 'ui.grid_columns must be an integer from 1 to 3'); else result.ui.grid_columns = raw.ui.grid_columns; end
        if not Util.is_finite_number(raw.ui.background_alpha) or raw.ui.background_alpha < 0.15 or raw.ui.background_alpha > 0.95 then table.insert(errors, 'ui.background_alpha must be between 0.15 and 0.95'); else result.ui.background_alpha = raw.ui.background_alpha; end
        if not Util.is_finite_number(raw.ui.font_scale) or raw.ui.font_scale < 0.60 or raw.ui.font_scale > 1.80 then table.insert(errors, 'ui.font_scale must be between 0.60 and 1.80'); else result.ui.font_scale = raw.ui.font_scale; end
    end

    if type(raw.thresholds) ~= 'table' then table.insert(errors, 'thresholds must be a table'); else
        unknown_fields(raw.thresholds, THRESHOLD_FIELDS, 'thresholds', errors);
        local warning, critical = raw.thresholds.warning_hp, raw.thresholds.critical_hp;
        if not Util.is_finite_number(warning) or not Util.is_finite_number(critical) or critical < 0 or warning > 100 or critical >= warning then table.insert(errors, 'thresholds require 0 <= critical_hp < warning_hp <= 100'); else result.thresholds.warning_hp, result.thresholds.critical_hp = warning, critical; end
    end

    if type(raw.actions) ~= 'table' then table.insert(errors, 'actions must be a table'); else
        unknown_fields(raw.actions, ACTION_KEYS, 'actions', errors);
        for key in pairs(ACTION_KEYS) do validate_binding(raw.actions[key], 'actions.' .. key, ACTION_FIELDS, result.actions[key], errors, true); end
    end

    if type(raw.remedies) ~= 'table' then table.insert(errors, 'remedies must be a table'); else
        unknown_fields(raw.remedies, Config.DEFAULT.remedies, 'remedies', errors);
        for key in pairs(Config.DEFAULT.remedies) do validate_binding(raw.remedies[key], 'remedies.' .. key, REMEDY_FIELDS, result.remedies[key], errors, false); end
    end

    if type(raw.review) ~= 'table' then table.insert(errors, 'review must be a table'); else
        unknown_fields(raw.review, REVIEW_FIELDS, 'review', errors);
        if type(raw.review.review_click_cast_enabled) ~= 'boolean' then table.insert(errors, 'review.review_click_cast_enabled must be boolean'); else result.review.review_click_cast_enabled = raw.review.review_click_cast_enabled; end
        if not Util.is_nonempty_string(raw.review.approval_status) then table.insert(errors, 'review.approval_status is required'); else result.review.approval_status = raw.review.approval_status; end
    end

    if type(raw.live_test) ~= 'table' then table.insert(errors, 'live_test must be a table'); else
        unknown_fields(raw.live_test, LIVE_TEST_FIELDS, 'live_test', errors);
        if type(raw.live_test.manual_dispatch_enabled) ~= 'boolean' then table.insert(errors, 'live_test.manual_dispatch_enabled must be boolean'); else result.live_test.manual_dispatch_enabled = raw.live_test.manual_dispatch_enabled; end
        if type(raw.live_test.emergency_stop) ~= 'boolean' then table.insert(errors, 'live_test.emergency_stop must be boolean'); else result.live_test.emergency_stop = raw.live_test.emergency_stop; end
    end

    if type(raw.direct_click) ~= 'table' then table.insert(errors, 'direct_click must be a table'); else
        unknown_fields(raw.direct_click, DIRECT_CLICK_FIELDS, 'direct_click', errors);
        if type(raw.direct_click.enabled) ~= 'boolean' then table.insert(errors, 'direct_click.enabled must be boolean'); else result.direct_click.enabled = raw.direct_click.enabled; end
        for _, key in ipairs({'left', 'right', 'middle'}) do validate_binding(raw.direct_click[key], 'direct_click.' .. key, DIRECT_CLICK_BINDING_FIELDS, result.direct_click[key], errors, false); end
    end

    if type(raw.colors) ~= 'table' then table.insert(errors, 'colors must be a table'); else
        unknown_fields(raw.colors, COLOR_KEYS, 'colors', errors);
        for key in pairs(COLOR_KEYS) do local normalized = normalize_color(raw.colors[key], 'colors.' .. key, errors); if normalized then result.colors[key] = normalized; end end
    end

    if #errors > 0 then return nil, errors; end
    return result, {};
end

return Config;
