local Spellbook = {};

local unpack_args = table.unpack or unpack;

local function call(object, method, ...)
    if not object then return nil; end
    local args, count = {...}, select('#', ...);
    local ok, value = pcall(function()
        local fn = object[method];
        if type(fn) ~= 'function' then return nil; end
        return fn(object, unpack_args(args, 1, count));
    end);
    if ok then return value; end
    return nil;
end

local function field(object, key)
    local ok, value = pcall(function() return object and object[key]; end);
    if ok then return value; end
    return nil;
end

local function has_spell(player, spell_id)
    local value = call(player, 'HasSpell', spell_id);
    if type(value) == 'boolean' then return value; end
    if type(value) == 'number' then return value ~= 0; end
    return nil;
end

-- Returns only definitive results.  Missing resource or spellbook data leaves a
-- spell unlisted so the normal user-configured rule remains available.
function Spellbook.availability(memory, rules)
    local availability = {};
    local player = call(memory, 'GetPlayer');
    local spell_data_ready = player and call(player, 'HasSpellData') or nil;
    if type(spell_data_ready) == 'number' then spell_data_ready = spell_data_ready ~= 0; end
    if not player or spell_data_ready ~= true then return availability; end
    local resources = AshitaCore and call(AshitaCore, 'GetResourceManager') or nil;
    if not resources then return availability; end

    for _, rule in pairs(rules or {}) do
        local spell_name = type(rule) == 'table' and rule.spell or nil;
        if type(spell_name) == 'string' and availability[spell_name] == nil then
            local resource = call(resources, 'GetSpellByName', spell_name, 0);
            local spell_id = tonumber(field(resource, 'Id') or field(resource, 'id'));
            if spell_id and spell_id >= 0 then
                local known = has_spell(player, spell_id);
                if known ~= nil then availability[spell_name] = known; end
            end
        end
    end
    return availability;
end

return Spellbook;
