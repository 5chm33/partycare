local root = '/home/ubuntu/repos/partycare';
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path;

_G.AshitaCore = {
    GetResourceManager = function()
        return {
            GetSpellByName = function(_, name)
                if name == 'Erase' then return {Id = 143}; end
                if name == 'Poisona' then return {Id = 14}; end
                return nil;
            end,
        };
    end,
};

local Spellbook = require('src.spellbook');
local PanelModel = require('src.panel_model');

local player = {
    HasSpellData = function() return 1; end,
    HasSpell = function(_, id) return id ~= 143; end,
};
local memory = {GetPlayer = function() return player; end};
local availability = Spellbook.availability(memory, {
    slow = {spell = 'Erase'}, poison = {spell = 'Poisona'},
});
assert(availability.Erase == false, 'unlearned Erase was not recorded as unavailable');
assert(availability.Poisona == true, 'learned Poisona was not recorded as available');

local model, errors = PanelModel.new();
assert(model and #errors == 0, 'panel model initialization failed');
assert(model:update_config(function(config)
    config.ui.refresh_pulse_enabled = true;
    config.ui.refresh_min_mp = 150;
end));
assert(model:update_members({{
    id = 1, name = 'Rdm', hp = 100, hp_max = 100, mp = 200, mp_max = 300,
    debuffs = {'slow', 'poison'}, refresh_known = true, has_refresh = false,
    spell_availability = availability,
}}));
local member = model:view().members[1];
assert(member.remedy_recommendation and member.remedy_recommendation.debuff == 'poison', 'unlearned Erase did not fall through to Poisona');
assert(member.refresh_missing == true, 'current MP above threshold did not enable Refresh alert');

local function icons(first)
    local values = {[1] = first, [2] = 255};
    return values;
end
local fake_player = {
    HasSpellData = function() return 1; end,
    HasSpell = function(_, id) return id ~= 143; end,
    GetStatusIcons = function() return icons(148); end,
    GetBuffs = function() return icons(148); end,
    GetRawStructure = function() return {StatusIcons = icons(148), Buffs = icons(148)}; end,
};
local fake_party = {
    GetMemberIsActive = function(_, slot) return slot == 0 and 1 or 0; end,
    GetMemberName = function(_, slot) return slot == 0 and 'Rdm' or nil; end,
    GetMemberServerId = function(_, slot) return slot == 0 and 1 or 0; end,
    GetMemberHPPercent = function() return 100; end,
    GetMemberMPPercent = function() return 50; end,
    GetMemberMP = function() return 200; end,
    GetStatusIconsServerId = function() return 0; end,
    GetRawStructureStatusIcons = function() return {Members = {}}; end,
};
_G.AshitaCore = {
    GetMemoryManager = function() return {GetPlayer = function() return fake_player; end, GetParty = function() return fake_party; end}; end,
    GetResourceManager = function() return {GetSpellByName = function(_, name) return name == 'Erase' and {Id = 143} or (name == 'Poisona' and {Id = 14} or nil); end}; end,
};
local Provider = require('src.ashita_party_provider');
local snapshot, snapshot_error = Provider.snapshot({slow = {spell = 'Erase'}, poison = {spell = 'Poisona'}});
assert(snapshot and not snapshot_error and #snapshot == 1, 'Ashita provider did not return the local member');
assert(snapshot[1].mp == 200 and snapshot[1].mp_max == 400, 'Ashita provider did not retain current and estimated maximum MP');
assert(#snapshot[1].debuffs == 0, 'generic Evasion Down icon created a remedy debuff');
assert(snapshot[1].refresh_known == true and snapshot[1].has_refresh == false, 'local Refresh absence was not identified');

print('Ashita spellbook and alert regression tests passed.');
