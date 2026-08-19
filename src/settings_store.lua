local Util = require('src.util');

local Store = {};

local function render(value, seen, indent)
    local value_type = type(value);
    if value_type == 'number' then
        assert(Util.is_finite_number(value), 'cannot save invalid number');
        return tostring(value);
    elseif value_type == 'string' then
        return string.format('%q', value);
    elseif value_type == 'boolean' then
        return tostring(value);
    elseif value_type ~= 'table' then
        error('unsupported settings value type: ' .. value_type);
    end

    seen = seen or {};
    assert(not seen[value], 'cannot save cyclic settings data');
    seen[value] = true;
    indent = indent or 0;
    local lines = {'{'};
    local padding = string.rep('  ', indent + 1);
    for _, key in ipairs(Util.sorted_keys(value)) do
        local rendered_key = type(key) == 'string' and key:match('^[A-Za-z_][A-Za-z0-9_]*$') and key
            or '[' .. render(key, seen, indent + 1) .. ']';
        table.insert(lines, padding .. rendered_key .. ' = ' .. render(value[key], seen, indent + 1) .. ',');
    end
    table.insert(lines, string.rep('  ', indent) .. '}');
    seen[value] = nil;
    return table.concat(lines, '\n');
end

function Store.save(path, data)
    if not Util.is_nonempty_string(path) or type(data) ~= 'table' then return false, 'valid settings path and table are required'; end
    local temporary = path .. '.tmp';
    local content_ok, content = pcall(function() return 'return ' .. render(data) .. '\n'; end);
    if not content_ok then return false, content; end

    local file, open_error = io.open(temporary, 'w');
    if not file then return false, open_error; end
    local wrote, write_error = file:write(content);
    local closed, close_error = file:close();
    if not wrote or not closed then
        os.remove(temporary);
        return false, write_error or close_error or 'failed to save settings';
    end

    local backup = path .. '.bak';
    os.remove(backup);
    local existing = io.open(path, 'r');
    local had_existing = existing ~= nil;
    if existing then
        existing:close();
        local moved, move_error = os.rename(path, backup);
        if not moved then os.remove(temporary); return false, move_error; end
    end
    local committed, commit_error = os.rename(temporary, path);
    if not committed then
        if had_existing then os.rename(backup, path); end
        os.remove(temporary);
        return false, commit_error;
    end
    os.remove(backup);
    return true, nil;
end

return Store;
