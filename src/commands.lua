local Commands = {};

local function trim(value)
    return value:match('^%s*(.-)%s*$');
end

function Commands.parse(raw)
    if type(raw) ~= 'string' then return nil; end
    local command = trim(raw);
    if command == '' then return nil; end
    local head, tail = command:match('^(%S+)%s*(.*)$');
    if not head then return nil; end
    head = head:lower();
    if head ~= '/partycare' and head ~= '/pc' then return nil; end

    local tokens = {};
    for token in tail:gmatch('%S+') do table.insert(tokens, token:lower()); end
    return {
        alias = head,
        action = tokens[1] or 'config',
        argument = tokens[2],
        raw = command,
    };
end

return Commands;
