local Util = require('src.util');

local Remedies = {};

local ALIASES = {
    paralyze = 'paralyze', paralysis = 'paralyze',
    gravity = 'gravity', slow = 'slow',
    silence = 'silence',
    blind = 'blind', blindness = 'blind',
    poison = 'poison', bio = 'bio', dia = 'dia',
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

function Remedies.recommend(member, rules)
    if type(rules) ~= 'table' then return nil, {}; end
    local candidates = {};
    for _, debuff in ipairs(Remedies.normalize_list(member)) do
        local rule = rules[debuff];
        if type(rule) == 'table' and rule.enabled and Util.is_nonempty_string(rule.spell) and Util.is_integer(rule.priority) then
            table.insert(candidates, {rule_id = debuff, debuff = debuff, spell = rule.spell, priority = rule.priority});
        end
    end
    table.sort(candidates, function(left, right)
        if left.priority ~= right.priority then return left.priority > right.priority; end
        return left.rule_id < right.rule_id;
    end);
    return candidates[1], candidates;
end

return Remedies;
