package.path = '/home/ubuntu/repos/partycare/?.lua;' .. package.path;

local Config = require('src.config');
local PanelModel = require('src.panel_model');

local model, errors = PanelModel.new(Config.DEFAULT);
assert(model and #errors == 0, 'panel model initialization failed');
assert(model:update_config(function(config)
    config.ui.enemy_dispel_alert_mode = true;
    config.ui.enemy_dispel_alert_preview = true;
    config.ui.enemy_dispel_x = 999;
    config.ui.enemy_dispel_y = 777;
    config.ui.refresh_pulse_enabled = true;
    config.ui.refresh_min_mp = 450;
    config.ui.refresh_early_pulse_enabled = false;
    config.ui.refresh_duration_seconds = 300;
    config.ui.refresh_early_seconds = 30;
end));
assert(model:reset_layout());
local ui = model:view().config.ui;
assert(ui.enemy_dispel_alert_mode == Config.DEFAULT.ui.enemy_dispel_alert_mode, 'enemy alert mode did not reset');
assert(ui.enemy_dispel_alert_preview == Config.DEFAULT.ui.enemy_dispel_alert_preview, 'enemy preview did not reset');
assert(ui.enemy_dispel_x == Config.DEFAULT.ui.enemy_dispel_x and ui.enemy_dispel_y == Config.DEFAULT.ui.enemy_dispel_y, 'enemy alert position did not reset');
assert(ui.refresh_pulse_enabled == Config.DEFAULT.ui.refresh_pulse_enabled, 'Refresh feature gate did not reset');
assert(ui.refresh_min_mp == Config.DEFAULT.ui.refresh_min_mp, 'Refresh MP threshold did not reset');
assert(ui.refresh_early_pulse_enabled == Config.DEFAULT.ui.refresh_early_pulse_enabled, 'early Refresh toggle did not reset');
assert(ui.refresh_duration_seconds == Config.DEFAULT.ui.refresh_duration_seconds, 'Refresh duration did not reset');
assert(ui.refresh_early_seconds == Config.DEFAULT.ui.refresh_early_seconds, 'Refresh lead time did not reset');

print('Layout reset regression tests passed.');
