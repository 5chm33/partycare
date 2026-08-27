local Spellbook = require('src.spellbook');
local Tracker = {};

local unpack_args = table.unpack or unpack;
local enemies = {};
local casts = {};
local now = 0;
local EFFECT_TTL = 300;
local TARGET_SCAN_INTERVAL = 0.20;
local next_party_target_scan_at = 0;

-- Only spells whose successful self-cast is a known removable magic effect are
-- tracked. This avoids treating arbitrary enemy casts as Dispel candidates.
local REMOVABLE_SELF_BUFFS = {
    ['protect'] = true, ['protect ii'] = true, ['protect iii'] = true, ['protect iv'] = true, ['protect v'] = true,
    ['protectra'] = true, ['protectra ii'] = true, ['protectra iii'] = true, ['protectra iv'] = true, ['protectra v'] = true,
    ['shell'] = true, ['shell ii'] = true, ['shell iii'] = true, ['shell iv'] = true, ['shell v'] = true,
    ['shellra'] = true, ['shellra ii'] = true, ['shellra iii'] = true, ['shellra iv'] = true, ['shellra v'] = true,
    ['haste'] = true, ['hastega'] = true, ['blink'] = true, ['stoneskin'] = true, ['aquaveil'] = true,
    ['phalanx'] = true, ['phalanx ii'] = true, ['ice spikes'] = true, ['blaze spikes'] = true,
    ['shock spikes'] = true, ['dread spikes'] = true, ['barfire'] = true, ['barblizzard'] = true,
    ['baraero'] = true, ['barstone'] = true, ['barthunder'] = true, ['barwater'] = true,
    ['enfire'] = true, ['enblizzard'] = true, ['enaero'] = true, ['enstone'] = true,
    ['enthunder'] = true, ['enwater'] = true,
};
local INTERRUPT_MESSAGES = {[0] = true, [16] = true, [84] = true, [106] = true};

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

local function normalize_name(value)
    if type(value) ~= 'string' then return nil; end
    return value:lower():gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '');
end

local function party_ids()
    local ids = {};
    local memory = AshitaCore and call(AshitaCore, 'GetMemoryManager') or nil;
    local party = call(memory, 'GetParty');
    for slot = 0, 17 do
        local id = tonumber(call(party, 'GetMemberServerId', slot));
        if id and id > 0 then ids[id] = true; end
    end
    return ids;
end

local function get_entity(index)
    local memory = AshitaCore and call(AshitaCore, 'GetMemoryManager') or nil;
    local entity = call(memory, 'GetEntity');
    if not entity or not index or index <= 0 then return nil; end
    local id = tonumber(call(entity, 'GetServerId', index));
    local name = call(entity, 'GetName', index);
    local hp = tonumber(call(entity, 'GetHPPercent', index));
    if not id or id <= 0 or type(name) ~= 'string' or name == '' or (hp and hp <= 0) then return nil; end
    return {id = id, target_index = index, name = name};
end

local function entity_index_from_id(server_id)
    local memory = AshitaCore and call(AshitaCore, 'GetMemoryManager') or nil;
    local entity = call(memory, 'GetEntity');
    if not entity or not server_id or server_id <= 0 then return nil; end
    -- Monster IDs encode their entity index, but validate the result and fall
    -- back to a bounded entity scan for nonstandard/spawned entities.
    local encoded = bit.band(server_id, 0xFFF);
    if encoded >= 0x900 then encoded = encoded - 0x100; end
    if encoded > 0 and tonumber(call(entity, 'GetServerId', encoded)) == server_id then return encoded; end
    for index = 1, 0x8FF do
        if tonumber(call(entity, 'GetServerId', index)) == server_id then return index; end
    end
    return nil;
end

local function track_index(index)
    local candidate = get_entity(index);
    if not candidate then return nil; end
    local party = party_ids();
    if party[candidate.id] then return nil; end
    local known = enemies[candidate.id] or {id = candidate.id, effects = {}};
    known.target_index = candidate.target_index;
    known.name = candidate.name;
    known.last_seen = now;
    enemies[candidate.id] = known;
    return known;
end

local function expire()
    for id, enemy in pairs(enemies) do
        for effect, applied_at in pairs(enemy.effects or {}) do
            if now - applied_at > EFFECT_TTL then enemy.effects[effect] = nil; end
        end
        if now - (enemy.last_seen or 0) > EFFECT_TTL then enemies[id] = nil; casts[id] = nil; end
    end
end

local function parse_action_packet(e)
    if not e or not e.data_raw or not e.size or not ashita or not ashita.bits then return nil; end
    local bit_data, bit_offset, max_length = e.data_raw, 40, e.size * 8;
    local function unpack_bits(length)
        if bit_offset + length >= max_length then max_length = 0; return 0; end
        local value = ashita.bits.unpack_be(bit_data, 0, bit_offset, length);
        bit_offset = bit_offset + length;
        return value;
    end
    local packet = {user_id = unpack_bits(32), targets = {}};
    local target_count = unpack_bits(6);
    bit_offset = bit_offset + 4;
    packet.type = unpack_bits(4);
    if packet.type == 8 or packet.type == 9 then
        -- Cast-start packets carry a 16-bit spell/ability ID followed by its
        -- 16-bit spell group. Both fields must be consumed before targets.
        packet.param = unpack_bits(16);
        packet.spell_group = unpack_bits(16);
    else
        packet.param = unpack_bits(32);
    end
    packet.recast = unpack_bits(32);
    for _ = 1, target_count do
        local target = {id = unpack_bits(32), actions = {}};
        local action_count = unpack_bits(4);
        if action_count == 0 then break; end
        for _ = 1, action_count do
            local action = {};
            unpack_bits(5); unpack_bits(12); unpack_bits(7); unpack_bits(3);
            action.param = unpack_bits(17);
            action.message = unpack_bits(10);
            unpack_bits(31);
            if unpack_bits(1) == 1 then unpack_bits(10); unpack_bits(17); unpack_bits(10); end
            if unpack_bits(1) == 1 then unpack_bits(10); unpack_bits(14); unpack_bits(10); end
            target.actions[#target.actions + 1] = action;
        end
        packet.targets[#packet.targets + 1] = target;
    end
    if max_length == 0 then return nil; end
    return packet;
end

local function spell_name(spell_id)
    local resources = AshitaCore and call(AshitaCore, 'GetResourceManager') or nil;
    local spell = call(resources, 'GetSpellById', spell_id);
    local name = field(field(spell, 'Name'), 1) or field(field(spell, 'Name'), 3);
    return normalize_name(name);
end

local function remember_self_buff(actor_id, spell_id)
    local name = spell_name(spell_id);
    if not name or not REMOVABLE_SELF_BUFFS[name] then return; end
    casts[actor_id] = {spell = name, started_at = now};
end

local function handle_parsed_action(packet)
    if not packet or not packet.user_id or packet.user_id <= 0 then return; end
    local party = party_ids();
    local actor_is_party = party[packet.user_id] == true;
    local actor_index = entity_index_from_id(packet.user_id);

    -- A mob acting on a party member, or a party member acting on a mob, is a
    -- party-engaged battle enemy. This does not require the local player target.
    for _, target in ipairs(packet.targets) do
        if actor_is_party and not party[target.id] then
            local target_index = entity_index_from_id(target.id);
            if target_index then track_index(target_index); end
        elseif not actor_is_party and party[target.id] and actor_index then
            track_index(actor_index);
        end
    end

    local enemy = enemies[packet.user_id];
    if not enemy then return; end
    local self_target = packet.targets[1] and packet.targets[1].id == packet.user_id;
    local action = packet.targets[1] and packet.targets[1].actions[1] or nil;
    if packet.type == 8 and self_target and action then
        remember_self_buff(packet.user_id, action.param);
    elseif packet.type == 4 and self_target then
        local pending = casts[packet.user_id];
        if pending then
            if not action or not INTERRUPT_MESSAGES[action.message] then
                enemy.effects[pending.spell] = now;
            end
            casts[packet.user_id] = nil;
        end
    end
end

Tracker.parse_action_packet = parse_action_packet;

Tracker.party_ids = party_ids;

function Tracker.handle_action_packet(e)
    handle_parsed_action(parse_action_packet(e));
end

-- Test-only hooks for deterministic packet-state validation. They consume the
-- same normalized action shape produced by the live parser.
Tracker._test_handle_parsed_action = handle_parsed_action;
Tracker._test_reset_clock = function(value) now = tonumber(value) or 0; Tracker.clear(); end

function Tracker.handle_mob_update_packet(e)
    if not e or e.id ~= 0x00E or not e.data or not struct then return; end
    local flags = struct.unpack('B', e.data, 0x0A + 1);
    if bit.band(flags, 0x02) ~= 0x02 then return; end
    local claim_id = struct.unpack('L', e.data, 0x2C + 1);
    if party_ids()[claim_id] then
        local index = struct.unpack('H', e.data, 0x08 + 1);
        track_index(index);
    end
end

local function find_log_confirmed_enemy_by_name(name)
    local wanted = normalize_name(name);
    if not wanted then return nil; end
    local memory = AshitaCore and call(AshitaCore, 'GetMemoryManager') or nil;
    local entity = call(memory, 'GetEntity');
    if not entity then return nil; end
    local party, visible_fallback = party_ids(), nil;
    for index = 1, 0x8FF do
        local entity_name = normalize_name(call(entity, 'GetName', index));
        if entity_name == wanted then
            local candidate = track_index(index);
            if candidate then
                local claim = tonumber(call(entity, 'GetClaimStatus', index)) or 0;
                local claim_id = bit.band(claim, 0xFFFF);
                if party[claim_id] then return candidate; end
                -- HorizonXI can omit a usable party claim owner. A log-confirmed
                -- named self-buff is still stronger evidence than no alert, so
                -- retain an exact visible-name fallback. The click-time target
                -- identity guard remains mandatory before Dispel can be sent.
                visible_fallback = visible_fallback or candidate;
            end
        end
    end
    return visible_fallback;
end

function Tracker.mark_effect_by_name(enemy_name, effect_name)
    local enemy = find_log_confirmed_enemy_by_name(enemy_name);
    if not enemy then return false; end
    local effect = normalize_name(effect_name) or 'potential buff';
    enemy.effects[effect] = now;
    enemy.last_seen = now;
    return true;
end

function Tracker.refresh_party_targets()
    -- IParty exposes every party/alliance member's active target index. Poll it
    -- at the snapshot cadence so the compact panel follows the party's battle
    -- target even when the local player has another target or no target at all.
    if now < next_party_target_scan_at then return; end
    next_party_target_scan_at = now + TARGET_SCAN_INTERVAL;
    local memory = AshitaCore and call(AshitaCore, 'GetMemoryManager') or nil;
    local party = call(memory, 'GetParty');
    for slot = 0, 17 do
        local index = tonumber(call(party, 'GetMemberTargetIndex', slot));
        if index and index > 0 then track_index(index); end
    end
end

function Tracker.update(delta)
    now = now + (tonumber(delta) or 0);
    Tracker.refresh_party_targets();
    expire();
end

function Tracker.clear()
    enemies = {};
    casts = {};
    next_party_target_scan_at = 0;
end

function Tracker.current()
    local memory = AshitaCore and call(AshitaCore, 'GetMemoryManager') or nil;
    local availability = Spellbook.availability(memory, {enemy_dispel = {spell = 'Dispel'}});
    -- A transient spellbook read should not make an explicitly enabled manual
    -- enemy panel invisible. Hide only when Dispel is definitively unavailable;
    -- the normal game command remains the final authority on castability.
    if availability.Dispel == false then return nil; end
    expire();
    local selected, selected_effect, selected_at = nil, nil, -1;
    local fallback, fallback_seen = nil, -1;
    for _, enemy in pairs(enemies) do
        if (enemy.last_seen or -1) > fallback_seen then fallback, fallback_seen = enemy, enemy.last_seen or -1; end
        for effect, applied_at in pairs(enemy.effects or {}) do
            if applied_at > selected_at then selected, selected_effect, selected_at = enemy, effect, applied_at; end
        end
    end
    -- A party-engaged enemy provides an intentional quick manual Dispel cue
    -- even before a recognized self-buff action has been observed. When one is
    -- observed, the effect name replaces this generic potential cue.
    selected = selected or fallback;
    if not selected then return nil; end
    return {
        id = selected.id,
        target_index = selected.target_index,
        name = selected.name,
        spell = 'Dispel',
        learned = true,
        action_available = true,
        detected_effect = selected_effect or 'potential buff',
        requires_current_target = true,
    };
end

return Tracker;
