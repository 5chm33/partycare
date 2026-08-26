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
    GetRawStructure = function() return {Members = {{MPMax = 360}}}; end,
};
_G.AshitaCore = {
    GetMemoryManager = function() return {GetPlayer = function() return fake_player; end, GetParty = function() return fake_party; end}; end,
    GetResourceManager = function() return {GetSpellByName = function(_, name) return name == 'Erase' and {Id = 143} or (name == 'Poisona' and {Id = 14} or nil); end}; end,
};
local Provider = require('src.ashita_party_provider');
local snapshot, snapshot_error = Provider.snapshot({slow = {spell = 'Erase'}, poison = {spell = 'Poisona'}});
assert(snapshot and not snapshot_error and #snapshot == 1, 'Ashita provider did not return the local member');
assert(snapshot[1].mp == 200 and snapshot[1].mp_max == 360, 'Ashita provider did not retain the direct maximum MP');
assert(#snapshot[1].debuffs == 0, 'generic Evasion Down icon created a remedy debuff');
assert(snapshot[1].refresh_known == true and snapshot[1].has_refresh == false, 'local Refresh absence was not identified');

local continuity_model, continuity_errors = PanelModel.new();
assert(continuity_model and #continuity_errors == 0, 'continuity model initialization failed');
assert(continuity_model:update_config(function(config)
    config.ui.refresh_pulse_enabled = true;
    config.ui.refresh_min_mp = 150;
end));
assert(continuity_model:update_members({{
    id = 2, name = 'Mage', hp = 100, hp_max = 100, mp = 220, mp_max = 300,
    refresh_known = true, has_refresh = false,
}}));
assert(continuity_model:view().members[1].refresh_missing == true, 'confirmed missing Refresh did not start pulse');
assert(continuity_model:update_members({{
    id = 2, name = 'Mage', hp = 100, hp_max = 100, mp = 220, mp_max = 300,
    refresh_known = false, has_refresh = false,
}}));
assert(continuity_model:view().members[1].refresh_missing == true, 'temporary unknown status stopped missing Refresh pulse');
assert(continuity_model:update_members({{
    id = 2, name = 'Mage', hp = 100, hp_max = 100, mp = 220, mp_max = 300,
    refresh_known = true, has_refresh = true,
}}));
assert(continuity_model:view().members[1].refresh_missing == false, 'confirmed Refresh reapplication did not stop pulse');

local max_mp_model, max_mp_errors = PanelModel.new();
assert(max_mp_model and #max_mp_errors == 0, 'maximum-MP model initialization failed');
assert(max_mp_model:update_config(function(config)
    config.ui.refresh_pulse_enabled = true;
    config.ui.refresh_min_mp = 150;
end));
assert(max_mp_model:update_members({{
    id = 3, name = 'Incidental MP', hp = 100, hp_max = 100, mp = 100, mp_max = 120,
    refresh_known = true, has_refresh = false,
}}));
assert(max_mp_model:view().members[1].refresh_missing == false, 'member below maximum-MP threshold pulsed');
assert(max_mp_model:update_members({{
    id = 3, name = 'Refresh Target', hp = 100, hp_max = 100, mp = 100, mp_max = 220,
    refresh_known = true, has_refresh = false,
}}));
assert(max_mp_model:view().members[1].refresh_missing == true, 'member above maximum-MP threshold did not pulse');

print('Ashita spellbook and alert regression tests passed.');
