local Provider = {};

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

local STATUS_TO_REMEDY_RULE = {
    [3] = 'poison', [4] = 'paralyze', [5] = 'blind', [6] = 'silence',
    [12] = 'gravity', [13] = 'slow', [134] = 'dia', [135] = 'bio',
};

local function debuffs_for_slot(party, slot)
    local icons = call(party, 'GetStatusIcons', slot);
    if type(icons) ~= 'table' then return {}; end
    local found, debuffs = {}, {};
    for _, status_id in ipairs(icons) do
        local rule_id = STATUS_TO_REMEDY_RULE[tonumber(status_id)];
        if rule_id and not found[rule_id] then found[rule_id] = true; table.insert(debuffs, rule_id); end
    end
    return debuffs;
end

local function memory_manager()
    if AshitaCore == nil then return nil; end
    return call(AshitaCore, 'GetMemoryManager');
end

function Provider.available()
    return memory_manager() ~= nil;
end

function Provider.snapshot()
    local memory = memory_manager();
    if not memory then return nil, 'Ashita party memory manager is unavailable'; end
    local party = call(memory, 'GetParty');
    if not party then return nil, 'Ashita party interface is unavailable'; end

    local members = {};
    for slot = 0, 5 do
        local active = call(party, 'GetMemberIsActive', slot);
        local name = call(party, 'GetMemberName', slot);
        if active == 1 and type(name) == 'string' and name:match('%S') then
            local hp_percent = tonumber(call(party, 'GetMemberHPPercent', slot)) or 0;
            local mp_percent = tonumber(call(party, 'GetMemberMPPercent', slot)) or 0;
            table.insert(members, {
                id = call(party, 'GetMemberServerId', slot) or slot,
                party_slot = slot,
                name = name,
                hp = hp_percent, hp_max = 100,
                mp = mp_percent, mp_max = 100,
                debuffs = debuffs_for_slot(party, slot),
            });
        end
    end
    return members, nil;
end

return Provider;
