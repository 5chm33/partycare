package.path = '/home/ubuntu/repos/partycare/?.lua;' .. package.path;

local remedy_rules = {
    paralyze = {spell = 'Paralyna'}, doom = {spell = 'Cursna'}, petrify = {spell = 'Stona'}, curse = {spell = 'Cursna'},
    plague = {spell = 'Viruna'}, disease = {spell = 'Viruna'}, gravity = {spell = 'Erase'}, bind = {spell = 'Erase'},
    slow = {spell = 'Erase'}, silence = {spell = 'Silena'}, blind = {spell = 'Blindna'}, poison = {spell = 'Poisona'},
    bio = {spell = 'Erase'}, dia = {spell = 'Erase'}, addle = {spell = 'Erase'}, flash = {spell = 'Erase'},
    stun = {spell = 'Erase'}, elegy = {spell = 'Erase'}, requiem = {spell = 'Erase'}, helix = {spell = 'Erase'},
    elemental_dot = {spell = 'Erase'}, stat_down = {spell = 'Erase'},
};

local spell_ids = {
    Paralyna = 15, Cursna = 20, Stona = 18, Viruna = 19, Erase = 143,
    Silena = 17, Blindna = 16, Poisona = 14,
};

local function make_player(main_job, main_level, sub_job, sub_level, known)
    return {
        HasSpellData = function() return 1; end,
        HasSpell = function(_, spell_id) return known[spell_id] ~= false; end,
        GetMainJob = function() return main_job; end,
        GetMainJobLevel = function() return main_level; end,
        GetSubJob = function() return sub_job; end,
        GetSubJobLevel = function() return sub_level; end,
    };
end

_G.AshitaCore = {
    GetResourceManager = function()
        return {
            -- Deliberately incomplete resource values ensure the audited
            -- standard remedy table, not an unreliable resource row, decides
            -- the live main/subjob level requirement.
            GetSpellByName = function(_, spell)
                local id = spell_ids[spell];
                return id and {Id = id, LevelRequired = {[6] = 1}} or nil;
            end,
        };
    end,
};

local Spellbook = require('src.spellbook');

local function availability_for(player)
    return Spellbook.availability({GetPlayer = function() return player; end}, remedy_rules);
end

-- Reported live-equivalent case: RDM 56 / WHM 28.  Paralyna, Blindna,
-- Silena, and Poisona are castable via WHM subjob; Cursna, Viruna, Stona,
-- and Erase must be hidden because their WHM requirements are higher.
local rdm_whm = availability_for(make_player(5, 56, 3, 28, {}));
assert(rdm_whm.Paralyna == true, 'RDM56/WHM28 Paralyna must be available');
assert(rdm_whm.Blindna == true, 'RDM56/WHM28 Blindna must be available');
assert(rdm_whm.Silena == true, 'RDM56/WHM28 Silena must be available');
assert(rdm_whm.Poisona == true, 'RDM56/WHM28 Poisona must be available');
assert(rdm_whm.Cursna == false, 'RDM56/WHM28 Cursna must be level-locked');
assert(rdm_whm.Viruna == false, 'RDM56/WHM28 Viruna must be level-locked');
assert(rdm_whm.Stona == false, 'RDM56/WHM28 Stona must be level-locked');
assert(rdm_whm.Erase == false, 'RDM56/WHM28 Erase must be level-locked');

-- A high-level White Mage should see every configured dedicated remedy.
local whm = availability_for(make_player(3, 50, 5, 25, {}));
for _, spell in ipairs({'Paralyna', 'Cursna', 'Stona', 'Viruna', 'Erase', 'Silena', 'Blindna', 'Poisona'}) do
    assert(whm[spell] == true, 'WHM50 ' .. spell .. ' was incorrectly excluded');
end

-- Learned-spell ownership is a hard gate even when job and level are valid.
local missing_paralyna = availability_for(make_player(3, 50, 5, 25, {[15] = false}));
assert(missing_paralyna.Paralyna == false, 'unlearned Paralyna must be excluded');

print('All configured remedy availability regression tests passed.');
