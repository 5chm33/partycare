local root = '/home/ubuntu/repos/partycare';
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path;

local Config = require('src.config');
local PanelModel = require('src.panel_model');
local Util = require('src.util');

local function check(condition, message)
    if not condition then error(message or 'assertion failed'); end
end

local raw = Util.copy(Config.DEFAULT);
local model, errors = PanelModel.new(raw);
check(model and #errors == 0, 'wheel-binding model did not initialize');
check(model:update_members({{
    id = 501, name = 'WheelTarget', hp = 100, hp_max = 100, mp = 100, mp_max = 100,
    spell_availability = {Refresh = false, Haste = false},
}}, 0), 'wheel-binding member update failed');

local up, up_error = model:request_direct_click(501, 'wheel_up', 1);
check(up ~= nil and up_error == nil and up.spell == 'Refresh', 'wheel-up must queue the configured manual Refresh action');
local down, down_error = model:request_direct_click(501, 'wheel_down', 2);
check(down ~= nil and down_error == nil and down.spell == 'Haste', 'wheel-down must queue the configured manual Haste action');

local prior = Util.copy(Config.DEFAULT);
prior.version = 22;
prior.direct_click.wheel_up = {spell = 'Regen', enabled = false};
prior.direct_click.wheel_down = {spell = 'Cure III', enabled = false};
local migrated, migration_errors = Config.validate(prior);
check(migrated and #migration_errors == 0, 'version 22 direct-click settings failed to migrate');
check(migrated.direct_click.wheel_up.spell == 'Refresh' and migrated.direct_click.wheel_up.enabled == true, 'migration must set wheel-up to Refresh');
check(migrated.direct_click.wheel_down.spell == 'Haste' and migrated.direct_click.wheel_down.enabled == true, 'migration must set wheel-down to Haste');

print('Wheel binding regression tests passed.');
