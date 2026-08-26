local Provider = {};
local PartyStatusCache = require('src.party_status_cache');
local Spellbook = require('src.spellbook');

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
    -- Generic stat-down icons (136-149, 167, 174-175, 189) are deliberately
    -- not mapped to a remedy. HorizonXI can expose them as local/transitional
    -- state, and one broad Erase rule cannot distinguish their actual source.
    [156] = 'flash', [186] = 'helix', [192] = 'requiem', [194] = 'elegy',
};

local function alliance_group(slot)
    if slot <= 5 then return 1; end
    if slot <= 11 then return 2; end
    return 3;
end

local REFRESH_STATUS_ID = 43;

local function has_status_icon(icons, wanted_status_id)
    if icons == nil then return false, false; end
    for index = 1, 32 do
        local ok, raw_id = pcall(function() return icons[index]; end);
        if not ok then return false, false; end
        local status_id = tonumber(raw_id);
        if status_id == 255 then return false, true; end
        if status_id == wanted_status_id then return true, true; end
    end
    return false, true;
end

local function decode_icons(icons)
    local found, debuffs, observed = {}, {}, 0;
    if icons == nil then return debuffs, observed, false; end
    -- Ashita can expose the 32-status array as a userdata-backed indexed source, not a plain Lua table.
    -- Read explicit one-based entries, matching maintained AshitaFrames behavior and the SDK's 32-entry contract.
    for index = 1, 32 do
        local ok, raw_id = pcall(function() return icons[index]; end);
        if not ok then return debuffs, observed, false; end
        local status_id = tonumber(raw_id);
        if status_id == 255 then break; end
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
            local icons = call(party, 'GetStatusIcons', record_index);
            local debuffs, meta = merge_status_sources({{name = 'party_status_icons', values = icons}});
            local has_refresh, refresh_known = has_status_icon(icons, REFRESH_STATUS_ID);
            records[server_id] = {debuffs = debuffs, meta = meta, has_refresh = has_refresh, refresh_known = refresh_known};
        end
    end

    -- Ashita also documents a raw five-member status structure. Use it only to supplement missing accessor records.
    local raw = call(party, 'GetRawStructureStatusIcons');
    if type(raw) == 'table' and type(raw.Members) == 'table' then
        for _, member in pairs(raw.Members) do
            local server_id = tonumber(type(member) == 'table' and member.ServerId or nil);
            if server_id and server_id > 0 and not records[server_id] then
                local debuffs, meta = merge_status_sources({{name = 'party_status_raw', values = member.StatusIcons}});
                local has_refresh, refresh_known = has_status_icon(member.StatusIcons, REFRESH_STATUS_ID);
                records[server_id] = {debuffs = debuffs, meta = meta, has_refresh = has_refresh, refresh_known = refresh_known};
            end
        end
    end
    return records;
end

local FALLBACK_ALLOWED_RULES = {
    poison = true, paralyze = true, blind = true, silence = true,
    petrify = true, disease = true, curse = true, doom = true, plague = true,
    bind = true, gravity = true, slow = true,
};

local function count_rule(records, rule_id)
    local count = 0;
    for _, record in pairs(records or {}) do
        for _, value in ipairs(record.debuffs or {}) do
            if value == rule_id then count = count + 1; break; end
        end
    end
    return count;
end

local function filter_fallback_debuffs(debuffs, allow_slow)
    local result = {};
    for _, rule_id in ipairs(debuffs or {}) do
        if FALLBACK_ALLOWED_RULES[rule_id] and (rule_id ~= 'slow' or allow_slow) then
            table.insert(result, rule_id);
        end
    end
    return result;
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

local function local_player_refresh(memory)
    local player = call(memory, 'GetPlayer');
    local raw = call(player, 'GetRawStructure');
    local sources = {
        call(player, 'GetStatusIcons'), call(player, 'GetBuffs'),
        type(raw) == 'table' and raw.StatusIcons or nil,
        type(raw) == 'table' and raw.Buffs or nil,
    };
    local known = false;
    for index = 1, 4 do
        local has_refresh, available = has_status_icon(sources[index], REFRESH_STATUS_ID);
        if available then
            known = true;
            if has_refresh then return true, true; end
        end
    end
    return false, known;
end

local function memory_manager()
    if AshitaCore == nil then return nil; end
    return call(AshitaCore, 'GetMemoryManager');
end

function Provider.available()
    return memory_manager() ~= nil;
end

function Provider.snapshot(remedy_rules)
    local memory = memory_manager();
    if not memory then return nil, 'Ashita party memory manager is unavailable'; end
    local party = call(memory, 'GetParty');
    if not party then return nil, 'Ashita party interface is unavailable'; end

    local spell_availability = Spellbook.availability(memory, remedy_rules);
    local memory_status_by_server_id = local_statuses_by_server_id(party);
    -- A Level Sync transition can write the same stale Slow value to several
    -- remote records.  A single fallback Slow is useful; a multi-member burst
    -- is treated as transitional until an authoritative packet replaces it.
    local fallback_slow_allowed = count_rule(memory_status_by_server_id, 'slow') == 1;
    local self_statuses, self_meta = local_player_statuses(memory);
    local self_has_refresh, self_refresh_known = local_player_refresh(memory);
    local members = {};
    for slot = 0, 17 do
        local active = call(party, 'GetMemberIsActive', slot);
        local name = call(party, 'GetMemberName', slot);
        if active == 1 and type(name) == 'string' and name:match('%S') then
            local group = alliance_group(slot);
            local server_id = tonumber(call(party, 'GetMemberServerId', slot)) or slot;
            local debuffs, status_meta = {}, {available = false, observed = 0, source = ''};
            local has_refresh, refresh_known = false, false;
            if group == 1 then
                if slot == 0 then
                    debuffs, status_meta = self_statuses, self_meta;
                    has_refresh, refresh_known = self_has_refresh, self_refresh_known;
                else
                    -- Remote party status icons are packet-backed.  The client-memory
                    -- records can temporarily retain or misassociate values while
                    -- Level Sync updates, which previously produced party-wide false
                    -- `Slow` / `Erase` recommendations.
                    local packet_statuses = PartyStatusCache.get(server_id);
                    if packet_statuses then
                        debuffs, status_meta = merge_status_sources({{
                            name = 'party_status_packet',
                            values = packet_statuses,
                        }});
                        has_refresh, refresh_known = has_status_icon(packet_statuses, REFRESH_STATUS_ID);
                    elseif memory_status_by_server_id[server_id] then
                        -- A 0x076 packet is not guaranteed to arrive immediately after
                        -- PartyCare loads.  Use the normal memory record for direct,
                        -- well-understood effects such as Poison.  Treat grouped or
                        -- derived effects (including stat-down) as packet-only because
                        -- HorizonXI can expose transient values for them during sync.
                        -- Keep a single Slow, but suppress a simultaneous multi-member
                        -- Slow burst until an authoritative packet replaces it.
                        debuffs = filter_fallback_debuffs(memory_status_by_server_id[server_id].debuffs, fallback_slow_allowed);
                        status_meta = memory_status_by_server_id[server_id].meta;
                        status_meta = {
                            available = status_meta.available,
                            observed = status_meta.observed,
                            source = status_meta.source .. ' (guarded memory fallback)',
                        };
                        has_refresh = memory_status_by_server_id[server_id].has_refresh == true;
                        refresh_known = memory_status_by_server_id[server_id].refresh_known == true;
                    end
                end
            end
            local hp_percent = tonumber(call(party, 'GetMemberHPPercent', slot)) or 0;
            local mp_percent = tonumber(call(party, 'GetMemberMPPercent', slot)) or 0;
            local current_mp = tonumber(call(party, 'GetMemberMP', slot)) or 0;
            local estimated_mp_max = mp_percent > 0 and math.max(current_mp, math.floor(current_mp * 100 / mp_percent + 0.5)) or math.max(current_mp, 1);
            table.insert(members, {
                id = server_id,
                party_slot = slot,
                alliance_group = group,
                name = name,
                hp = hp_percent, hp_max = 100,
                mp = current_mp, mp_max = estimated_mp_max,
                debuffs = debuffs,
                status_feed_available = status_meta.available,
                status_icon_count = status_meta.observed,
                status_source = status_meta.source,
                has_refresh = has_refresh,
                refresh_known = refresh_known,
                spell_availability = spell_availability,
            });
        end
    end
    return members, nil;
end

return Provider;
