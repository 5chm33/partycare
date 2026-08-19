local ResourceStyle = {};

local GREEN = {0.18, 0.78, 0.35, 1.00};
local YELLOW = {0.95, 0.76, 0.12, 1.00};
local RED = {0.92, 0.20, 0.22, 1.00};
local MP_HIGH = {0.22, 0.58, 0.96, 1.00};
local MP_MID = {0.30, 0.72, 0.62, 1.00};
local MP_LOW = {0.96, 0.66, 0.16, 1.00};
local MP_CRITICAL = {0.90, 0.30, 0.24, 1.00};

local function clamp(value)
    if type(value) ~= 'number' then return 0; end
    if value < 0 then return 0; end
    if value > 1 then return 1; end
    return value;
end

function ResourceStyle.hp_color(percent, warning_percent, critical_percent)
    percent = clamp(percent);
    local warning = clamp((warning_percent or 55) / 100);
    local critical = clamp((critical_percent or 30) / 100);
    if percent <= critical then return RED, 'critical'; end
    if percent <= warning then return YELLOW, 'warning'; end
    return GREEN, 'healthy';
end

function ResourceStyle.mp_color(percent)
    percent = clamp(percent);
    if percent <= 0.20 then return MP_CRITICAL, 'critical'; end
    if percent <= 0.45 then return MP_LOW, 'low'; end
    if percent <= 0.70 then return MP_MID, 'medium'; end
    return MP_HIGH, 'high';
end

function ResourceStyle.bar_label(prefix, current, maximum, font_scale)
    if type(maximum) ~= 'number' or maximum <= 0 then return prefix .. ' —'; end
    local percent = math.floor((current / maximum) * 100 + 0.5);
    if (font_scale or 1) < 0.88 then
        return string.format('%s %d%%', prefix, percent);
    end
    return string.format('%s %d / %d (%d%%)', prefix, current, maximum, percent);
end

return ResourceStyle;
