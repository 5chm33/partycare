local root = '/home/ubuntu/repos/partycare';
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path;

local party_id, enemy_id = 1001, 0x10000C8;
local claim_owner = party_id;
local entity = {
    GetServerId = function(_, index) return index == 200 and enemy_id or 0; end,
    GetName = function(_, index) return index == 200 and 'Rumble Crawler' or nil; end,
    GetHPPercent = function(_, index) return index == 200 and 100 or 0; end,
    GetClaimStatus = function(_, index) return index == 200 and claim_owner or 0; end,
};
local player = {
    HasSpellData = function() return 1; end,
    HasSpell = function(_, id) return id == 260; end,
    GetMainJob = function() return 5; end, GetMainJobLevel = function() return 50; end,
    GetSubJob = function() return 3; end, GetSubJobLevel = function() return 25; end,
};
_G.bit = {band = function(value, mask)
    if mask == 0xFFF then return value % 0x1000; end
    if mask == 0xFFFF then return value % 0x10000; end
    return 0;
end};
_G.AshitaCore = {
    GetMemoryManager = function()
        return {
            GetPlayer = function() return player; end,
            GetParty = function() return {GetMemberServerId = function(_, slot) return slot == 0 and party_id or 0; end}; end,
            GetEntity = function() return entity; end,
        };
    end,
    GetResourceManager = function()
        return {GetSpellByName = function(_, name) return name == 'Dispel' and {Id = 260, LevelRequired = {[6] = 32}} or nil; end};
    end,
};

local BattleTracker = require('src.battle_enemy_tracker');
local LogTracker = require('src.enemy_log_tracker');
BattleTracker._test_reset_clock(0);
assert(LogTracker.handle_text({message_modified = 'Rumble Crawler Cocoon -> Rumble Crawler', injected = false}) == true, 'Cocoon combat-log evidence did not map to the claimed enemy');
local alert = BattleTracker.current();
assert(alert and alert.name == 'Rumble Crawler' and alert.detected_effect == 'cocoon', 'Cocoon log did not create the named manual Dispel alert');
assert(LogTracker.handle_text({message = 'Rumble Crawler hits you for 10 points of damage.', injected = false}) == false, 'unrelated combat text created an enemy Dispel alert');
claim_owner = 0;
BattleTracker._test_reset_clock(0);
assert(LogTracker.handle_text({message = 'Rumble Crawler Cocoon -> Rumble Crawler', injected = false}) == true, 'exact visible Cocoon caster was discarded because party claim ownership was unavailable');
assert(BattleTracker.current() and BattleTracker.current().detected_effect == 'cocoon', 'unclaimed visible Cocoon caster did not reach the Dispel alert');
print('Enemy log tracker regression tests passed.');
