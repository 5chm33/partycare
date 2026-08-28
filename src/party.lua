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

    local debuff_labels = {};
    if type(raw.debuff_labels) == 'table' then
        for rule_id, label in pairs(raw.debuff_labels) do
            if Util.is_nonempty_string(rule_id) and Util.is_nonempty_string(label) then debuff_labels[rule_id] = label; end
        end
    end

    local spell_availability = {};
    if type(raw.spell_availability) == 'table' then
        for spell, known in pairs(raw.spell_availability) do
            if Util.is_nonempty_string(spell) and type(known) == 'boolean' then spell_availability[spell] = known; end
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
        debuff_labels = debuff_labels,
        status_feed_available = raw.status_feed_available == true,
        status_icon_count = Util.is_integer(raw.status_icon_count) and math.max(0, raw.status_icon_count) or 0,
        status_source = type(raw.status_source) == 'string' and raw.status_source or '',
        has_refresh = raw.has_refresh == true,
        refresh_known = raw.refresh_known == true,
        refresh_early = raw.refresh_early == true,
        has_haste = raw.has_haste == true,
        haste_known = raw.haste_known == true,
        haste_early = raw.haste_early == true,
        spell_availability = spell_availability,
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

function Party.decorate_members(members, thresholds, ui)
    local decorated = {};
    for index, member in ipairs(members) do
        decorated[index] = Util.copy(member);
        decorated[index].severity = Party.severity(member, thresholds);
        decorated[index].needs_attention = decorated[index].severity == 'warning' or decorated[index].severity == 'critical';
        local alertable = decorated[index].active and decorated[index].hp > 0;
        local above_refresh_threshold = decorated[index].mp_max > (ui and ui.refresh_min_mp or 150);
        local confirmed_missing = decorated[index].refresh_known == true and decorated[index].has_refresh ~= true;
        local early_refresh = decorated[index].refresh_early == true;
        local refresh_feature_enabled = ui and ui.refresh_pulse_enabled == true;
        decorated[index].refresh_missing = alertable and refresh_feature_enabled
            and above_refresh_threshold
            and (confirmed_missing or early_refresh);
        decorated[index].refresh_alert_kind = alertable and refresh_feature_enabled and above_refresh_threshold
            and (confirmed_missing and 'missing' or (early_refresh and 'expiring' or nil))
            or nil;

        -- Haste is a separate, explicitly opt-in party upkeep cue. HorizonXI
        -- does not reliably expose remote Haste or the local spellbook during
        -- every update, so this display reminder must not silently disappear
        -- because either source is temporarily absent. The actual wheel-down
        -- Haste command remains learned-and-level-usable gated before casting.
        -- Refresh retains visual priority whenever both cues would apply.
        local haste_feature_enabled = ui and ui.haste_pulse_enabled == true;
        local haste_missing_or_unknown = decorated[index].has_haste ~= true;
        local early_haste = decorated[index].haste_early == true;
        decorated[index].haste_alert_kind = alertable and haste_feature_enabled
            and (haste_missing_or_unknown and 'haste_missing' or (early_haste and 'haste_expiring' or nil))
            or nil;
        decorated[index].upkeep_alert_kind = decorated[index].refresh_alert_kind or decorated[index].haste_alert_kind;
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
