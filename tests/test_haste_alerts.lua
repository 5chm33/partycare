package.path = '/home/ubuntu/repos/partycare/?.lua;/home/ubuntu/repos/partycare/?/init.lua;' .. package.path;

local Config = require('src.config');
local Party = require('src.party');
local PanelModel = require('src.panel_model');
local Util = require('src.util');

local function check(condition, message)
    if not condition then error(message or 'assertion failed'); end
end

local function base_ui()
    local ui = Util.copy(Config.DEFAULT.ui);
    ui.haste_pulse_enabled = true;
    ui.haste_early_pulse_enabled = true;
    ui.refresh_pulse_enabled = true;
    ui.refresh_min_mp = 150;
    return ui;
end

local function raw_member(overrides)
    local member = {
        id = 1001, name = 'TestMember', hp = 500, hp_max = 500, mp = 200, mp_max = 200,
        active = true, has_refresh = true, refresh_known = true,
        has_haste = false, haste_known = true,
        spell_availability = {Haste = true},
    };
    for key, value in pairs(overrides or {}) do member[key] = value; end
    return member;
end

local function decorated(overrides, ui)
    local members = assert(Party.normalize_members({raw_member(overrides)}));
    return Party.decorate_members(members, Config.DEFAULT.thresholds, ui or base_ui())[1];
end

-- Haste-only missing state is yellow (represented by its specific alert kind).
local haste_missing = decorated();
check(haste_missing.haste_alert_kind == 'haste_missing', 'missing Haste must receive the Haste-only alert');
check(haste_missing.upkeep_alert_kind == 'haste_missing', 'Haste-only state must drive the displayed upkeep alert');

-- Refresh must win the visible hierarchy when both effects are missing.
local refresh_first = decorated({has_refresh = false, refresh_known = true});
check(refresh_first.refresh_alert_kind == 'missing', 'missing Refresh must receive the primary alert');
check(refresh_first.haste_alert_kind == 'haste_missing', 'missing Haste remains tracked while Refresh is missing');
check(refresh_first.upkeep_alert_kind == 'missing', 'Refresh must take visual priority over Haste');

-- Once Refresh is clear, early Haste timing may appear as the yellow blinking cue.
local early_haste = decorated({haste_early = true});
check(early_haste.upkeep_alert_kind == 'haste_missing', 'confirmed missing Haste takes priority over an early Haste marker');
local haste_expiring = decorated({has_haste = true, haste_known = true, haste_early = true});
check(haste_expiring.upkeep_alert_kind == 'haste_expiring', 'expiring Haste must drive the yellow early-warning cue');

-- Disabling Haste must remove all Haste-driven card styling.
local disabled_ui = base_ui();
disabled_ui.haste_pulse_enabled = false;
local disabled_haste = decorated({}, disabled_ui);
check(disabled_haste.haste_alert_kind == nil and disabled_haste.upkeep_alert_kind == nil, 'disabled Haste alerts must not style member cards');

-- Haste is an explicitly opt-in upkeep reminder even when Ashita cannot
-- report spellbook data. Attempting its wheel action remains separately gated.
local level_locked = decorated({spell_availability = {Haste = false}});
check(level_locked.haste_alert_kind == 'haste_missing', 'enabled Haste reminders must remain visible even if the Haste action is level-locked');
local loading_spellbook = decorated({spell_availability = {}});
check(loading_spellbook.haste_alert_kind == 'haste_missing', 'an enabled Haste alert must remain visible while Ashita spellbook data is temporarily unavailable');

-- Observed Haste duration reaches early warning at 165 seconds then clears at reapplication.
local config = Util.copy(Config.DEFAULT);
config.ui.haste_pulse_enabled = true;
config.ui.haste_early_pulse_enabled = true;
config.ui.haste_duration_seconds = 180;
config.ui.haste_early_seconds = 15;
local model = assert(PanelModel.new(config));
check(model:update_members({raw_member({has_haste = true, haste_known = true})}, 0));
check(model:update_members({raw_member({has_haste = true, haste_known = true})}, 165));
check(model:view().members[1].upkeep_alert_kind == 'haste_expiring', 'Haste must blink during its final 15 seconds');
check(model:mark_haste_reapplied(1001, 166));
check(model:view().members[1].haste_early ~= true, 'Haste reapplication must immediately clear the early cue');

print('Haste alert regression tests passed.');
