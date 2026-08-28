local root = '/home/ubuntu/repos/partycare';
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path;

local bits = {};
local function append(value, width)
    for shift = width - 1, 0, -1 do bits[#bits + 1] = math.floor(value / (2 ^ shift)) % 2; end
end
-- 40 header bits, then the fields parsed by PartyCare's shared 0x028 reader.
append(0, 40);
append(1001, 32); -- actor
append(1, 6); append(0, 4); append(8, 4); -- Type 8 cast start
append(109, 16); append(0, 16); append(0, 32); -- Refresh spell, group, recast
append(2002, 32); append(1, 4); -- one party target, one action
append(0, 5); append(0, 12); append(0, 7); append(0, 3);
append(109, 17); append(1, 10); append(0, 31); append(0, 1); append(0, 1);
append(0, 8); -- parser requires trailing room beyond final field

_G.ashita = {bits = {unpack_be = function(data, _, offset, width)
    local value = 0;
    for i = offset + 1, offset + width do value = value * 2 + (data.bits[i] or 0); end
    return value;
end}};
_G.bit = {band = function(value, mask) return mask == 0xFFF and (value % 0x1000) or 0; end};
_G.AshitaCore = {GetMemoryManager = function() return {}; end};

local Tracker = require('src.battle_enemy_tracker');
local packet = Tracker.parse_action_packet({data_raw = {bits = bits}, size = math.ceil(#bits / 8)});
assert(packet and packet.type == 8 and packet.user_id == 1001, 'Type 8 action header was not parsed');
assert(packet.targets and packet.targets[1] and packet.targets[1].id == 2002, 'Type 8 action target became misaligned');
assert(packet.targets[1].actions[1].param == 109, 'Type 8 action spell parameter became misaligned');
print('Action packet alignment regression tests passed.');
