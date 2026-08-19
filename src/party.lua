local Util = require('src.util');

local Party = {};

local function member_key(member)
    return tostring(member.id);
end

function Party.normalize_member(raw, position)
    if type(raw) ~= 'table' then return nil, 'member must be a table'; end
    position = position or 1;
    if raw.id == nil or not Util.is_nonempty_string(raw.name) then return nil, 'member id and name are required'; end
    if not Util.is_finite_number(raw.hp) or not Util.is_finite_number(raw.hp_max) or raw.hp_max <= 0 then
        return nil, 'member hp and hp_max are required';
    end

    local mp = raw.mp;
    local mp_max = raw.mp_max;
    if mp == nil then mp = 0; end
    if mp_max == nil then mp_max = 0; end
    if not Util.is_finite_number(mp) or not Util.is_finite_number(mp_max) or mp_max < 0 then
        return nil, 'member mp values are invalid';
    end

    local party_slot = raw.party_slot;
    if party_slot == nil then party_slot = position - 1; end
    if not Util.is_integer(party_slot) or party_slot < 0 or party_slot > 17 then return nil, 'party_slot must be an integer from 0 to 17'; end
    local alliance_group = raw.alliance_group;
    if alliance_group == nil then alliance_group = math.floor(party_slot / 6) + 1; end
    if not Util.is_integer(alliance_group) or alliance_group < 1 or alliance_group > 3 then return nil, 'alliance_group must be an integer from 1 to 3'; end

    local debuffs = {};
    if raw.debuffs ~= nil then
        if type(raw.debuffs) ~= 'table' then return nil, 'member debuffs must be a table when supplied'; end
        for _, debuff in ipairs(raw.debuffs) do
            if not Util.is_nonempty_string(debuff) then return nil, 'member debuffs must contain non-empty strings'; end
            table.insert(debuffs, debuff);
        end
    end

    local normalized = {
        id = raw.id,
        name = raw.name,
        position = position,
        party_slot = party_slot,
        alliance_group = alliance_group,
        hp = Util.clamp(raw.hp, 0, raw.hp_max),
        hp_max = raw.hp_max,
        mp = mp_max == 0 and 0 or Util.clamp(mp, 0, mp_max),
        mp_max = mp_max,
        active = raw.active ~= false,
        status = type(raw.status) == 'string' and raw.status or '',
        debuffs = debuffs,
    };
    normalized.hp_percent = normalized.hp / normalized.hp_max * 100;
    normalized.mp_percent = normalized.mp_max == 0 and 0 or normalized.mp / normalized.mp_max * 100;
    return normalized, nil;
end

function Party.normalize_members(raw_members)
    if type(raw_members) ~= 'table' then return nil, {'members must be a table'}; end
    local members = {};
    local seen = {};
    local errors = {};

    for position, raw in ipairs(raw_members) do
        local member, error_message = Party.normalize_member(raw, position);
        if not member then
            table.insert(errors, 'member ' .. position .. ': ' .. error_message);
        elseif seen[member_key(member)] then
            table.insert(errors, 'member ' .. position .. ': duplicate member id');
        else
            seen[member_key(member)] = true;
            table.insert(members, member);
        end
    end

    if #errors > 0 then return nil, errors; end
    return members, {};
end

function Party.severity(member, thresholds)
    if not member.active then return 'inactive'; end
    if member.hp <= 0 then return 'critical'; end
    if member.hp_percent <= thresholds.critical_hp then return 'critical'; end
    if member.hp_percent <= thresholds.warning_hp then return 'warning'; end
    return 'healthy';
end

function Party.decorate_members(members, thresholds)
    local decorated = {};
    for index, member in ipairs(members) do
        decorated[index] = Util.copy(member);
        decorated[index].severity = Party.severity(member, thresholds);
        decorated[index].needs_attention = decorated[index].severity == 'warning' or decorated[index].severity == 'critical';
    end
    return decorated;
end

function Party.find_member(members, id)
    local wanted = tostring(id);
    for _, member in ipairs(members or {}) do
        if tostring(member.id) == wanted then return member; end
    end
    return nil;
end

return Party;
