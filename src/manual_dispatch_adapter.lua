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

function Adapter:dispatch(intent, live_test)
    if type(live_test) ~= 'table' or live_test.manual_dispatch_enabled ~= true then
        return false, 'manual dispatch is disabled';
    end
    if live_test.emergency_stop == true then return false, 'emergency stop is active'; end
    if not self.chat_manager or type(self.chat_manager.QueueCommand) ~= 'function' then
        return false, 'Ashita chat manager is unavailable';
    end
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
