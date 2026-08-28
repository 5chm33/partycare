--[[
    PartyCare Party Status Cache

    Holds the server-authoritative local-party buff records received in packet
    0x076.  PartyCare uses this for remote party members instead of decoding
    transient client-memory status records, which can be stale while Level Sync
    is being applied or refreshed.
]]
local Cache = {};

local statuses_by_server_id = {};

local function read_status_packet(event)
    if type(event) ~= 'table' or event.id ~= 0x076 then return false; end
    if type(event.data) ~= 'string' or type(event.data_raw) ~= 'string' then return false; end
    if not struct or not ashita or not ashita.bits or type(ashita.bits.unpack_be) ~= 'function' then return false; end

    local next_statuses = {};
    local ok = pcall(function()
        for record_index = 0, 4 do
            -- Ashita's packet offsets are one-based for struct.unpack.
            local member_offset = 0x04 + (0x30 * record_index) + 1;
            local server_id = tonumber(struct.unpack('L', event.data, member_offset));
            if server_id and server_id > 0 then
                local statuses, reached_end = {}, false;
                for status_index = 0, 31 do
                    if reached_end then break; end
                    local high_bits = tonumber(ashita.bits.unpack_be(event.data_raw, member_offset + 7, status_index * 2, 2)) or 0;
                    local low_bits = tonumber(struct.unpack('B', event.data, member_offset + 0x10 + status_index)) or 0;
                    local status_id = (high_bits * 256) + low_bits;
                    if status_id == 255 then
                        reached_end = true;
                    elseif status_id > 0 then
                        table.insert(statuses, status_id);
                    end
                end
                next_statuses[server_id] = statuses;
            end
        end
    end);

    if not ok then return false; end
    statuses_by_server_id = next_statuses;
    return true;
end

function Cache.update(event)
    return read_status_packet(event);
end

function Cache.get(server_id)
    return statuses_by_server_id[tonumber(server_id)];
end

function Cache.clear()
    statuses_by_server_id = {};
end

return Cache;
