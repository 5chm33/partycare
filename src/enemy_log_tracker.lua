local BattleEnemyTracker = require('src.battle_enemy_tracker');

local Tracker = {};

-- Monster abilities and spells that produce removable positive effects. The
-- text event gives us an immediate, server-presented confirmation even when
-- the local player is not targeting the enemy.
local REMOVABLE_EFFECTS = {
    ['cocoon'] = 'cocoon', ['metallic body'] = 'metallic body', ['stoneskin'] = 'stoneskin',
    ['blink'] = 'blink', ['haste'] = 'haste', ['protect'] = 'protect', ['shell'] = 'shell',
    ['phalanx'] = 'phalanx', ['ice spikes'] = 'ice spikes', ['blaze spikes'] = 'blaze spikes',
    ['shock spikes'] = 'shock spikes', ['dread spikes'] = 'dread spikes', ['aquaveil'] = 'aquaveil',
    ['mighty guard'] = 'mighty guard', ['warm-up'] = 'warm-up', ['berserk'] = 'berserk',
};

local function clean(message)
    if type(message) ~= 'string' then return nil; end
    return message:gsub('[%c]', ' '):gsub('%s+', ' '):lower();
end

local function find_effect(message)
    for phrase, effect in pairs(REMOVABLE_EFFECTS) do
        if message:find(phrase, 1, true) then return effect; end
    end
    return nil;
end

local function source_name(message, effect)
    -- Battle log formats vary by client and filters. Prefer the text before the
    -- named action; screenshots such as "Rumble Crawler Cocoon -> ..." follow
    -- this form. A fallback handles "Rumble Crawler uses Cocoon".
    local before = message:match('^%s*(.-)%s+' .. effect:gsub('(%W)', '%%%1'));
    if before and before:match('%S') then
        before = before:gsub('%s+uses%s*$', ''):gsub('%s+casts%s*$', ''):gsub('%s+$', '');
        return before;
    end
    return nil;
end

function Tracker.handle_text(event)
    if not event or event.injected then return false; end
    -- Ashita text hooks can expose the player-visible line only as
    -- message_modified. Prefer it, then retain the raw message fallback for
    -- clients and tests that provide message directly.
    local message = clean(event.message_modified or event.message);
    if not message then return false; end
    local effect = find_effect(message);
    if not effect then return false; end
    local enemy_name = source_name(message, effect);
    if not enemy_name then return false; end
    return BattleEnemyTracker.mark_effect_by_name(enemy_name, effect);
end

return Tracker;
