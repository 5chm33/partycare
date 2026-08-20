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
    local found, debuffs, observed = {}, {}, 0;
    if type(icons) ~= 'table' then return debuffs, observed, false; end
    -- pairs intentionally supports bindings that expose zero-indexed status arrays.
    for _, raw_id in pairs(icons) do
        local status_id = tonumber(raw_id);
        if status_id and status_id > 0 then
            observed = observed + 1;
            local rule_id = STATUS_TO_REMEDY_RULE[status_id];
            if rule_id and not found[rule_id] then
                found[rule_id] = true;
                table.insert(debuffs, rule_id);
            end
        end
    end
    table.sort(debuffs);
    return debuffs, observed, true;
end

local function merge_status_sources(sources)
    local found, debuffs, observed, names, available = {}, {}, 0, {}, false;
    for _, source in ipairs(sources) do
        local decoded, count, is_available = decode_icons(source.values);
        if is_available then
            available = true;
            table.insert(names, source.name);
            observed = observed + count;
            for _, rule_id in ipairs(decoded) do
                if not found[rule_id] then found[rule_id] = true; table.insert(debuffs, rule_id); end
            end
        end
    end
    table.sort(debuffs);
    return debuffs, {available = available, observed = observed, source = table.concat(names, ' + ')};
end

local function local_statuses_by_server_id(party)
    local records = {};
    for record_index = 0, 4 do
        local server_id = tonumber(call(party, 'GetStatusIconsServerId', record_index));
        if server_id and server_id > 0 then
            local debuffs, meta = merge_status_sources({{name = 'party_status_icons', values = call(party, 'GetStatusIcons', record_index)}});
            records[server_id] = {debuffs = debuffs, meta = meta};
        end
    end

    -- Ashita also documents a raw five-member status structure. Use it only to supplement missing accessor records.
    local raw = call(party, 'GetRawStructureStatusIcons');
    if type(raw) == 'table' and type(raw.Members) == 'table' then
        for _, member in pairs(raw.Members) do
            local server_id = tonumber(type(member) == 'table' and member.ServerId or nil);
            if server_id and server_id > 0 and not records[server_id] then
                local debuffs, meta = merge_status_sources({{name = 'party_status_raw', values = member.StatusIcons}});
                records[server_id] = {debuffs = debuffs, meta = meta};
            end
        end
    end
    return records;
end

local function local_player_statuses(memory)
    local player = call(memory, 'GetPlayer');
    local raw = call(player, 'GetRawStructure');
    return merge_status_sources({
        {name = 'player_status_icons', values = call(player, 'GetStatusIcons')},
        {name = 'player_buffs', values = call(player, 'GetBuffs')},
        {name = 'player_raw_status_icons', values = type(raw) == 'table' and raw.StatusIcons or nil},
        {name = 'player_raw_buffs', values = type(raw) == 'table' and raw.Buffs or nil},
    });
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
    local self_statuses, self_meta = local_player_statuses(memory);
    local members = {};
    for slot = 0, 17 do
        local active = call(party, 'GetMemberIsActive', slot);
        local name = call(party, 'GetMemberName', slot);
        if active == 1 and type(name) == 'string' and name:match('%S') then
            local group = alliance_group(slot);
            local server_id = tonumber(call(party, 'GetMemberServerId', slot)) or slot;
            local debuffs, status_meta = {}, {available = false, observed = 0, source = ''};
            if group == 1 then
                if slot == 0 then
                    debuffs, status_meta = self_statuses, self_meta;
                elseif status_by_server_id[server_id] then
                    debuffs, status_meta = status_by_server_id[server_id].debuffs, status_by_server_id[server_id].meta;
                end
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
                status_feed_available = status_meta.available,
                status_icon_count = status_meta.observed,
                status_source = status_meta.source,
            });
        end
    end
    return members, nil;
end

return Provider;
