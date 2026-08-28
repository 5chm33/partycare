package.path = '/home/ubuntu/repos/partycare/?.lua;' .. package.path;
-- Ashita exposes LuaJIT's bit library; provide only the entity-index operation
-- needed by this standalone Lua test process.
_G.bit = {band = function(value, mask) return mask == 0xFFF and (value % 0x1000) or 0; end};

local party_id = 1001;
local enemy_id = 0x10000C8;
local entities = {
    [100] = {id = party_id, name = 'Rdm', hp = 100},
    [200] = {id = enemy_id, name = 'Rumble Crawler', hp = 100},
};
local fake_player = {
    HasSpellData = function() return 1; end,
    HasSpell = function(_, id) return id == 266; end,
    GetMainJob = function() return 5; end,
    GetMainJobLevel = function() return 50; end,
    GetSubJob = function() return 3; end,
    GetSubJobLevel = function() return 25; end,
};
local fake_party = {
    GetMemberServerId = function(_, slot) return slot == 0 and party_id or 0; end,
};
local fake_entity = {
    GetServerId = function(_, index) return entities[index] and entities[index].id or 0; end,
    GetName = function(_, index) return entities[index] and entities[index].name or nil; end,
    GetHPPercent = function(_, index) return entities[index] and entities[index].hp or 0; end,
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
        return {
            GetSpellByName = function(_, name)
                return name == 'Dispel' and {Id = 266, LevelRequired = {[6] = 32}} or nil;
            end,
            GetSpellById = function(_, id)
                return id == 123 and {Name = {[1] = 'Haste'}} or nil;
            end,
        };
    end,
};

local Tracker = require('src.battle_enemy_tracker');
Tracker._test_reset_clock(0);

-- A party member acts on the mob: it becomes tracked even though this test
-- never provides a local selected target.
Tracker._test_handle_parsed_action({
    user_id = party_id, type = 4,
    targets = {{id = enemy_id, actions = {{param = 0, message = 1}}}},
});
local potential = Tracker.current();
assert(potential and potential.name == 'Rumble Crawler' and potential.detected_effect == 'potential buff', 'party-engaged enemy did not expose the expected manual potential-Dispel button');

-- The tracked enemy begins and completes Haste on itself.
Tracker._test_handle_parsed_action({
    user_id = enemy_id, type = 8,
    targets = {{id = enemy_id, actions = {{param = 123, message = 1}}}},
});
Tracker._test_handle_parsed_action({
    user_id = enemy_id, type = 4,
    targets = {{id = enemy_id, actions = {{param = 0, message = 1}}}},
});
local alert = Tracker.current();
assert(alert and alert.name == 'Rumble Crawler', 'unfocused party-engaged enemy name was not exposed');
assert(alert.detected_effect == 'haste' and alert.action_available == true, 'confirmed self-buff did not enable manual Dispel alert');

Tracker.clear();
assert(Tracker.current() == nil, 'zone or explicit tracker clear did not hide the enemy alert');
print('Battle enemy tracker regression tests passed.');
