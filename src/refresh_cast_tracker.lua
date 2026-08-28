local BattleEnemyTracker = require('src.battle_enemy_tracker');

local Tracker = {};
local unpack_args = table.unpack or unpack;
local pending_by_caster = {};
local INTERRUPT_MESSAGES = {[0] = true, [16] = true, [84] = true, [106] = true};

local function call(object, method, ...)
    if not object then return nil; end
    local args = {...};
    local ok, value = pcall(function()
        local fn = object[method];
        if type(fn) ~= 'function' then return nil; end
        return fn(object, unpack_args(args));
    end);
    if ok then return value; end
    return nil;
end

local function spell_kind(spell_id)
    local resources = AshitaCore and call(AshitaCore, 'GetResourceManager') or nil;
    local spell = call(resources, 'GetSpellById', spell_id);
    local name = spell and spell.Name and (spell.Name[1] or spell.Name[3]) or nil;
    if type(name) ~= 'string' then return nil; end
    name = name:lower();
    if name == 'refresh' or name == 'refresh ii' or name == 'refresh iii' then return 'refresh'; end
    if name == 'haste' then return 'haste'; end
    return nil;
end

-- The callback receives `kind`, target server ID, and observed time. The
-- parser emits the same normalized packet shape used by the battle tracker.
local function handle_parsed_packet(packet, party_ids, now, on_confirmed_upkeep)
    if not packet or not party_ids or party_ids[packet.user_id] ~= true then return; end
    local target = packet.targets and packet.targets[1] or nil;
    local action = target and target.actions and target.actions[1] or nil;
    local kind = packet.type == 8 and action and spell_kind(action.param) or nil;
    if kind and target and party_ids[target.id] == true then
        -- Record cast start so an early recast immediately suppresses an old
        -- warning. The subsequent status icon remains the authoritative state.
        pending_by_caster[packet.user_id] = {target_id = target.id, kind = kind, started_at = now};
        if type(on_confirmed_upkeep) == 'function' then on_confirmed_upkeep(kind, target.id, now); end
        return;
    end
    if packet.type == 4 then
        local pending = pending_by_caster[packet.user_id];
        if not pending then return; end
        pending_by_caster[packet.user_id] = nil;
        if target and target.id == pending.target_id and (not action or not INTERRUPT_MESSAGES[action.message]) and type(on_confirmed_upkeep) == 'function' then
            on_confirmed_upkeep(pending.kind, pending.target_id, now);
        end
    end
end

function Tracker.handle_packet(event, party_ids, now, on_confirmed_upkeep)
    local packet = BattleEnemyTracker.parse_action_packet and BattleEnemyTracker.parse_action_packet(event) or nil;
    handle_parsed_packet(packet, party_ids, now, on_confirmed_upkeep);
end

Tracker._test_handle_parsed_packet = handle_parsed_packet;

function Tracker.clear()
    pending_by_caster = {};
end

return Tracker;
