local Util = require('src.util');

local Intents = {};
Intents.KIND = 'MANUAL_CLICK_CAST_REQUEST';

function Intents.new()
    return {selected_member_id = nil, sequence = 0, audit = {}};
end

function Intents.select(state, member)
    assert(type(state) == 'table', 'intent state is required');
    if type(member) ~= 'table' or member.id == nil then return false, 'valid member is required'; end
    state.selected_member_id = member.id;
    table.insert(state.audit, {kind = 'MEMBER_SELECTED', member_id = member.id});
    return true, nil;
end

function Intents.clear_selection(state)
    assert(type(state) == 'table', 'intent state is required');
    state.selected_member_id = nil;
    table.insert(state.audit, {kind = 'SELECTION_CLEARED'});
end

function Intents.request(state, action_key, action, member, now, review_enabled)
    assert(type(state) == 'table', 'intent state is required');
    if not Util.is_nonempty_string(action_key) then return nil, 'action key is required'; end
    if type(action) ~= 'table' or not Util.is_nonempty_string(action.label) or not Util.is_nonempty_string(action.spell) then
        return nil, 'validated action binding is required';
    end
    if type(member) ~= 'table' or member.id == nil then return nil, 'valid member is required'; end
    if not Util.is_finite_number(now) or now < 0 then return nil, 'non-negative timestamp is required'; end

    state.sequence = state.sequence + 1;
    local intent = {
        kind = Intents.KIND,
        sequence = state.sequence,
        at = now,
        action_key = action_key,
        action_label = action.label,
        spell = action.spell,
        member_id = member.id,
        member_name = member.name,
        party_slot = member.party_slot,
        alliance_group = member.alliance_group,
        review_click_cast_enabled = review_enabled == true,
    };
    table.insert(state.audit, Util.copy(intent));
    return intent, nil;
end

function Intents.drain_audit(state)
    assert(type(state) == 'table', 'intent state is required');
    local audit = Util.copy(state.audit);
    state.audit = {};
    return audit;
end

return Intents;
