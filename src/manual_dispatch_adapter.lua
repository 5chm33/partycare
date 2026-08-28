local Util = require('src.util');

local Adapter = {};
Adapter.__index = Adapter;

local function safe_spell(spell)
    return Util.is_nonempty_string(spell) and spell:match("^[%a%d %-%']+$") ~= nil;
end

function Adapter.new(chat_manager)
    return setmetatable({chat_manager = chat_manager, audit = {}}, Adapter);
end

local function target_token(intent)
    if intent.target_kind == 'current_target' then return '<t>', nil; end
    if not Util.is_integer(intent.party_slot) or intent.party_slot < 0 or intent.party_slot > 17 then
        return nil, 'party slot must be an integer from 0 to 17';
    end
    if intent.party_slot <= 5 then return string.format('<p%d>', intent.party_slot), nil; end
    if intent.party_slot <= 11 then return string.format('<a1%d>', intent.party_slot - 6), nil; end
    return string.format('<a2%d>', intent.party_slot - 12), nil;
end

function Adapter.build_command(intent)
    if type(intent) ~= 'table' or intent.kind ~= 'MANUAL_CLICK_CAST_REQUEST' then return nil, 'unsupported intent'; end
    if not safe_spell(intent.spell) then return nil, 'spell contains unsupported characters'; end
    local target, target_error = target_token(intent);
    if not target then return nil, target_error; end
    return string.format('/ma "%s" %s', intent.spell, target), nil;
end

local function current_target_matches(intent)
    if intent.target_kind ~= 'current_target' then return true, nil; end
    if not AshitaCore or type(intent.member_id) ~= 'number' then return false, 'select the displayed enemy before casting'; end
    local memory = AshitaCore:GetMemoryManager();
    local target = memory and memory:GetTarget();
    local entity = memory and memory:GetEntity();
    if not target or not entity then return false, 'target data is unavailable; select the displayed enemy before casting'; end
    local index = target:GetTargetIndex(0);
    local server_id = index and entity:GetServerId(index) or nil;
    if tonumber(server_id) ~= intent.member_id then
        return false, 'select ' .. tostring(intent.member_name) .. ' before clicking Dispel';
    end
    return true, nil;
end

function Adapter:dispatch(intent, live_test)
    if type(live_test) ~= 'table' or live_test.manual_dispatch_enabled ~= true then
        return false, 'manual dispatch is disabled';
    end
    if live_test.emergency_stop == true then return false, 'emergency stop is active'; end
    if not self.chat_manager or type(self.chat_manager.QueueCommand) ~= 'function' then
        return false, 'Ashita chat manager is unavailable';
    end
    local target_matches, target_error = current_target_matches(intent);
    if not target_matches then return false, target_error; end
    local command, command_error = Adapter.build_command(intent);
    if not command then return false, command_error; end
    self.chat_manager:QueueCommand(1, command);
    table.insert(self.audit, {sequence = intent.sequence, command = command, member_name = intent.member_name, spell = intent.spell, alliance_group = intent.alliance_group});
    return true, command;
end

function Adapter:drain_audit()
    local audit = self.audit;
    self.audit = {};
    return audit;
end

return Adapter;
