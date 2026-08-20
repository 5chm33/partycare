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
    [7] = 'petrify', [8] = 'disease', [9] = 'curse', [10] = 'stun',
    [11] = 'bind', [12] = 'gravity', [13] = 'slow', [15] = 'doom', [21] = 'addle', [31] = 'plague',
    [128] = 'elemental_dot', [129] = 'elemental_dot', [130] = 'elemental_dot',
    [131] = 'elemental_dot', [132] = 'elemental_dot', [133] = 'elemental_dot',
    [134] = 'dia', [135] = 'bio',
    [136] = 'stat_down', [137] = 'stat_down', [138] = 'stat_down', [139] = 'stat_down',
    [140] = 'stat_down', [141] = 'stat_down', [142] = 'stat_down', [144] = 'stat_down',
    [145] = 'stat_down', [146] = 'stat_down', [147] = 'stat_down', [148] = 'stat_down',
    [149] = 'stat_down', [156] = 'flash', [167] = 'stat_down', [174] = 'stat_down',
    [175] = 'stat_down', [186] = 'helix', [189] = 'stat_down', [192] = 'requiem', [194] = 'elegy',
};

local function alliance_group(slot)
    if slot <= 5 then return 1; end
    if slot <= 11 then return 2; end
    return 3;
end

local function decode_icons(icons)
    local found, debuffs = {}, {};
    if type(icons) ~= 'table' then return debuffs; end
    for _, raw_id in ipairs(icons) do
        local rule_id = STATUS_TO_REMEDY_RULE[tonumber(raw_id)];
        if rule_id and not found[rule_id] then
            found[rule_id] = true;
            table.insert(debuffs, rule_id);
        end
    end
    return debuffs;
end

local function local_statuses_by_server_id(party)
    local records = {};
    -- The five status records are not aligned to the six local-party slots. Associate them by server ID.
    for record_index = 0, 4 do
        local server_id = tonumber(call(party, 'GetStatusIconsServerId', record_index));
        if server_id and server_id > 0 then
            records[server_id] = decode_icons(call(party, 'GetStatusIcons', record_index));
        end
    end
    return records;
end

local function local_player_statuses(memory)
    local player = call(memory, 'GetPlayer');
    return decode_icons(call(player, 'GetBuffs'));
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

    local status_by_server_id = local_statuses_by_server_id(party);
    local self_statuses = local_player_statuses(memory);
    local members = {};
    for slot = 0, 17 do
        local active = call(party, 'GetMemberIsActive', slot);
        local name = call(party, 'GetMemberName', slot);
        if active == 1 and type(name) == 'string' and name:match('%S') then
            local group = alliance_group(slot);
            local server_id = tonumber(call(party, 'GetMemberServerId', slot)) or slot;
            local debuffs = {};
            if group == 1 then
                debuffs = slot == 0 and self_statuses or (status_by_server_id[server_id] or {});
            end
            local hp_percent = tonumber(call(party, 'GetMemberHPPercent', slot)) or 0;
            local mp_percent = tonumber(call(party, 'GetMemberMPPercent', slot)) or 0;
            table.insert(members, {
                id = server_id,
                party_slot = slot,
                alliance_group = group,
                name = name,
                hp = hp_percent, hp_max = 100,
                mp = mp_percent, mp_max = 100,
                debuffs = debuffs,
            });
        end
    end
    return members, nil;
end

return Provider;
