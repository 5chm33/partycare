package.path = '/home/ubuntu/repos/partycare/?.lua;' .. package.path;

local learned_dispel = true;
local fake_player = {
    HasSpellData = function() return 1; end,
    HasSpell = function(_, spell_id) return spell_id == 260 and learned_dispel; end,
    GetMainJob = function() return 5; end,
    GetMainJobLevel = function() return 56; end,
    GetSubJob = function() return 3; end,
    GetSubJobLevel = function() return 28; end,
};
local fake_party = {
    GetMemberServerId = function(_, slot) return slot == 0 and 5001 or 0; end,
    GetMemberTargetIndex = function(_, slot) return slot == 0 and 777 or 0; end,
};
local fake_entity = {
    GetServerId = function(_, index) return index == 777 and 400001 or 0; end,
    GetName = function(_, index) return index == 777 and 'Rumble Crawler' or nil; end,
    GetHPPercent = function(_, index) return index == 777 and 85 or 0; end,
};
_G.AshitaCore = {
    GetMemoryManager = function()
        return {
            GetPlayer = function() return fake_player; end,
            GetParty = function() return fake_party; end,
            GetEntity = function() return fake_entity; end,
        };
    end,
    GetResourceManager = function()
        return {GetSpellByName = function(_, name)
            return name == 'Dispel' and {Id = 260, LevelRequired = {[6] = 32}} or nil;
        end};
    end,
};

local Tracker = require('src.battle_enemy_tracker');
Tracker._test_reset_clock(0);
Tracker.update(0.25);
local enemy = Tracker.current();
assert(enemy and enemy.id == 400001, 'party member target did not populate the battle enemy tracker');
assert(enemy.name == 'Rumble Crawler', 'party member target name was not preserved');
assert(enemy.detected_effect == 'potential buff', 'unobserved party target should offer the potential-buff Dispel cue');

learned_dispel = false;
assert(Tracker.current() == nil, 'definitively unavailable Dispel must suppress the compact action');

print('Party target enemy discovery regression tests passed.');
