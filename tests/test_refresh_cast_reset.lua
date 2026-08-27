local root = '/home/ubuntu/repos/partycare';
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path;

_G.AshitaCore = {
    GetResourceManager = function()
        return {
            GetSpellById = function(_, id) return id == 109 and {Name = {[1] = 'Refresh'}} or nil; end,
        };
    end,
};

local PanelModel = require('src.panel_model');
local RefreshCastTracker = require('src.refresh_cast_tracker');
local model, errors = PanelModel.new();
assert(model and #errors == 0, 'Refresh cast reset model did not initialize');
assert(model:update_config(function(config)
    config.ui.refresh_pulse_enabled = true;
    config.ui.refresh_min_mp = 150;
    config.ui.refresh_early_pulse_enabled = true;
    config.ui.refresh_duration_seconds = 150;
    config.ui.refresh_early_seconds = 15;
end));

local active = {{id = 2, name = 'Mage', hp = 100, hp_max = 100, mp = 100, mp_max = 300, refresh_known = true, has_refresh = true}};
assert(model:update_members(active, 0));
assert(model:update_members(active, 135));
assert(model:view().members[1].refresh_alert_kind == 'expiring', 'test setup did not reach the 15-second early cue');

RefreshCastTracker.clear();
local party = {[1] = true, [2] = true};
RefreshCastTracker._test_handle_parsed_packet({user_id = 1, type = 8, targets = {{id = 2, actions = {{param = 109, message = 1}}}}}, party, 136, function(kind, member_id, applied_at)
    if kind == 'refresh' then model:mark_refresh_reapplied(member_id, applied_at); end
end);
assert(model:view().members[1].refresh_missing == false, 'confirmed early Refresh cast start did not clear the alert immediately');
RefreshCastTracker._test_handle_parsed_packet({user_id = 1, type = 4, targets = {{id = 2, actions = {{param = 0, message = 1}}}}}, party, 137, function(kind, member_id, applied_at)
    if kind == 'refresh' then model:mark_refresh_reapplied(member_id, applied_at); end
end);
assert(model:view().members[1].refresh_missing == false, 'Refresh completion reintroduced an already-cleared alert');
assert(model:update_members(active, 260));
assert(model:view().members[1].refresh_alert_kind == nil, 'refreshed timer reached the early cue before its new observed duration');
assert(model:update_members(active, 272));
assert(model:view().members[1].refresh_alert_kind == 'expiring', 'refreshed timer did not re-enter the early cue at the new 15-second lead');

local disabled_model, disabled_errors = PanelModel.new();
assert(disabled_model and #disabled_errors == 0, 'disabled Refresh model did not initialize');
assert(disabled_model:update_config(function(config)
    config.ui.refresh_pulse_enabled = false;
end));
assert(disabled_model:update_members({{id = 9, name = 'Non Rdm', hp = 100, hp_max = 100, mp = 100, mp_max = 300, refresh_known = true, has_refresh = false}}, 0));
assert(disabled_model:view().members[1].refresh_alert_kind == nil and disabled_model:view().members[1].refresh_missing == false, 'disabled Refresh feature still applied purple alert state');

print('Refresh cast reset regression tests passed.');
