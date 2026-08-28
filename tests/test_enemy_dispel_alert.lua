package.path = '/home/ubuntu/repos/partycare/?.lua;' .. package.path;

local Config = require('src.config');
local PanelModel = require('src.panel_model');
local Adapter = require('src.manual_dispatch_adapter');

local known_dispel = true;
local fake_player = {
    HasSpellData = function() return 1; end,
    HasSpell = function(_, spell_id) return spell_id == 260 and known_dispel; end,
    GetMainJob = function() return 5; end,
    GetMainJobLevel = function() return 50; end,
    GetSubJob = function() return 3; end,
    GetSubJobLevel = function() return 25; end,
};
local fake_target = {
    GetTargetIndex = function(_, slot) return slot == 0 and 777 or 0; end,
};
local fake_entity = {
    GetName = function(_, index) return index == 777 and 'Buffed Crab' or nil; end,
    GetServerId = function(_, index) return index == 777 and 123456 or 0; end,
};
local fake_party = {
    GetMemberTargetIndex = function() return 0; end,
};
_G.AshitaCore = {
    GetMemoryManager = function()
        return {
            GetPlayer = function() return fake_player; end,
            GetTarget = function() return fake_target; end,
            GetEntity = function() return fake_entity; end,
            GetParty = function() return fake_party; end,
        };
    end,
    GetResourceManager = function()
        return {GetSpellByName = function(_, name) return name == 'Dispel' and {Id = 260, LevelRequired = {[6] = 32}} or nil; end};
    end,
};

local EnemyProvider = require('src.ashita_enemy_provider');
local enemy = EnemyProvider.snapshot();
assert(enemy and enemy.id == 123456 and enemy.name == 'Buffed Crab', 'selected enemy was not exposed for manual Dispel');
assert(enemy.action_available == true and enemy.learned == true, 'learned Dispel did not enable enemy action');

local model, errors = PanelModel.new(Config.DEFAULT);
assert(model and #errors == 0, 'enemy alert model initialization failed');
assert(model:update_config(function(config)
    config.ui.enemy_dispel_alert_mode = true;
end));
assert(model:update_enemy(enemy));
local intent, intent_error = model:request_enemy_dispel(1);
assert(intent and not intent_error, 'manual enemy Dispel intent was not created');
assert(intent.target_kind == 'current_target' and intent.member_name == 'Buffed Crab', 'enemy Dispel intent targeted the wrong entity');
local command, command_error = Adapter.build_command(intent);
assert(command == '/ma "Dispel" <t>' and not command_error, 'enemy Dispel did not remain a current-target manual command');

known_dispel = false;
assert(EnemyProvider.snapshot() == nil, 'unlearned Dispel unexpectedly showed an enemy action');
assert(model:update_enemy(nil));
local unavailable, unavailable_error = model:request_enemy_dispel(2);
assert(unavailable == nil and unavailable_error == 'no actionable enemy target', 'hidden-idle enemy state remained actionable');

print('Enemy Dispel alert regression tests passed.');
