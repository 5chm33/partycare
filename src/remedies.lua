local Util = require('src.util');

local Remedies = {};

local ALIASES = {
    paralyze = 'paralyze', paralysis = 'paralyze',
    doom = 'doom', petrify = 'petrify', petrification = 'petrify',
    curse = 'curse', plague = 'plague', disease = 'disease',
    gravity = 'gravity', weight = 'gravity', bind = 'bind', slow = 'slow',
    silence = 'silence', blind = 'blind', blindness = 'blind', poison = 'poison',
    bio = 'bio', dia = 'dia', addle = 'addle', flash = 'flash', stun = 'stun',
    elegy = 'elegy', requiem = 'requiem', helix = 'helix',
    burn = 'elemental_dot', frost = 'elemental_dot', choke = 'elemental_dot',
    rasp = 'elemental_dot', shock = 'elemental_dot', drown = 'elemental_dot',
    elemental_dot = 'elemental_dot',
    str_down = 'stat_down', dex_down = 'stat_down', vit_down = 'stat_down',
    agi_down = 'stat_down', int_down = 'stat_down', mnd_down = 'stat_down', chr_down = 'stat_down',
    max_hp_down = 'stat_down', max_mp_down = 'stat_down', accuracy_down = 'stat_down',
    attack_down = 'stat_down', evasion_down = 'stat_down', defense_down = 'stat_down',
    magic_def_down = 'stat_down', magic_acc_down = 'stat_down', magic_atk_down = 'stat_down',
    max_tp_down = 'stat_down', stat_down = 'stat_down',
};

local function canonical(value)
    if type(value) ~= 'string' then return nil; end
    local normalized = value:lower():gsub('^%s+', ''):gsub('%s+$', '');
    return ALIASES[normalized];
end

function Remedies.normalize_list(member)
    local found, output = {}, {};
    local source = type(member) == 'table' and member.debuffs or nil;
    if type(source) == 'table' then
        for _, value in ipairs(source) do
            local key = canonical(value);
            if key and not found[key] then found[key] = true; table.insert(output, key); end
        end
    end
    local legacy = type(member) == 'table' and canonical(member.status) or nil;
    if legacy and not found[legacy] then table.insert(output, legacy); end
    table.sort(output);
    return output;
end

function Remedies.recommend(member, rules, spell_availability)
    if type(rules) ~= 'table' then return nil, {}; end
    local candidates = {};
    for _, debuff in ipairs(Remedies.normalize_list(member)) do
        local rule = rules[debuff];
        local known = nil;
        if type(rule) == 'table' and type(spell_availability) == 'table' then known = spell_availability[rule.spell]; end
        if type(rule) == 'table' and rule.enabled and Util.is_nonempty_string(rule.spell) and Util.is_integer(rule.priority) and known ~= false then
            table.insert(candidates, {rule_id = debuff, debuff = debuff, spell = rule.spell, priority = rule.priority, spell_known = known});
        end
    end
    table.sort(candidates, function(left, right)
        if left.priority ~= right.priority then return left.priority > right.priority; end
        return left.rule_id < right.rule_id;
    end);
    return candidates[1], candidates;
end

return Remedies;
