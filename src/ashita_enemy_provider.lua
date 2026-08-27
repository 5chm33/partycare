local Spellbook = require('src.spellbook');

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

local function field(object, key)
    local ok, value = pcall(function() return object and object[key]; end);
    if ok then return value; end
    return nil;
end

local function current_party_server_ids(party)
    local ids = {};
    for slot = 0, 17 do
        local server_id = tonumber(call(party, 'GetMemberServerId', slot));
        if server_id and server_id > 0 then ids[server_id] = true; end
    end
    return ids;
end

local function selected_target(target)
    local raw = call(target, 'GetRawStructure');
    local raw_target = type(raw) == 'table' and type(raw.Targets) == 'table' and raw.Targets[1] or nil;
    local index = tonumber(call(target, 'GetTargetIndex', 0)) or tonumber(field(raw_target, 'Index'));
    local server_id = tonumber(call(target, 'GetServerId', 0)) or tonumber(field(raw_target, 'ServerId')) or tonumber(call(target, 'GetWindowServerId'));
    return index, server_id;
end

local function selected_target_name(target, entity, index)
    local name = call(entity, 'GetName', index);
    if type(name) == 'string' and name ~= '' then return name; end
    local raw_entity = call(entity, 'GetRawEntity', index);
    name = field(raw_entity, 'Name');
    if type(name) == 'string' and name ~= '' then return name; end
    name = call(target, 'GetWindowName');
    if type(name) == 'string' and name ~= '' then return name; end
    return nil;
end

-- Returns the selected non-party target only when Ashita definitively reports
-- that Dispel is currently usable. The panel is a manual convenience control;
-- it does not automatically cast, retarget, or claim that a buff is present.
function Provider.snapshot()
    if not AshitaCore then return nil; end
    local memory = call(AshitaCore, 'GetMemoryManager');
    if not memory then return nil; end
    local target = call(memory, 'GetTarget');
    local entity = call(memory, 'GetEntity');
    local party = call(memory, 'GetParty');
    if not target or not entity then return nil; end

    local availability = Spellbook.availability(memory, {enemy_dispel = {spell = 'Dispel'}});
    if availability.Dispel ~= true then return nil; end

    local target_index, server_id = selected_target(target);
    if not target_index or target_index <= 0 then return nil; end
    server_id = server_id or tonumber(call(entity, 'GetServerId', target_index));
    local name = selected_target_name(target, entity, target_index);
    if type(name) ~= 'string' or name == '' then return nil; end

    local party_ids = current_party_server_ids(party);
    if server_id and server_id > 0 and party_ids[server_id] then return nil; end
    -- Some Ashita target layouts do not expose a server ID for a fresh target.
    -- The target index remains sufficient to render a manual <t> action.
    local stable_id = server_id and server_id > 0 and server_id or target_index;

    return {
        id = stable_id,
        target_index = target_index,
        name = name,
        spell = 'Dispel',
        learned = true,
        action_available = true,
    };
end

return Provider;
