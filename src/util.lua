local Util = {};

function Util.copy(value, seen)
    if type(value) ~= 'table' then return value; end
    seen = seen or {};
    if seen[value] then return seen[value]; end
    local result = {};
    seen[value] = result;
    for key, child in pairs(value) do
        result[Util.copy(key, seen)] = Util.copy(child, seen);
    end
    return result;
end

function Util.clamp(value, minimum, maximum)
    if value < minimum then return minimum; end
    if value > maximum then return maximum; end
    return value;
end

function Util.is_finite_number(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge;
end

function Util.is_integer(value)
    return Util.is_finite_number(value) and value % 1 == 0;
end

function Util.is_nonempty_string(value)
    return type(value) == 'string' and value:match('%S') ~= nil;
end

function Util.table_count(value)
    local count = 0;
    for _ in pairs(value or {}) do count = count + 1; end
    return count;
end

function Util.sorted_keys(value)
    local keys = {};
    for key in pairs(value or {}) do table.insert(keys, key); end
    table.sort(keys, function(left, right) return tostring(left) < tostring(right); end);
    return keys;
end

return Util;
