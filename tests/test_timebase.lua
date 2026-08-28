package.path = '/home/ubuntu/repos/partycare/?.lua;' .. package.path;

local readings = {100.00, 100.01, 100.05, 100.55, 101.55, 201.55, 200.00};
local position = 0;
local Timebase = require('src.timebase');
local clock = Timebase.new(function()
    position = position + 1;
    return readings[position];
end);

local delta, now = clock:step();
assert(delta == 0 and now == 0, 'first timing sample must establish baseline without advancing');
delta, now = clock:step();
assert(math.abs(delta - 0.01) < 0.0001 and math.abs(now - 0.01) < 0.0001, 'high-FPS elapsed time was not retained');
delta, now = clock:step();
assert(math.abs(delta - 0.04) < 0.0001 and math.abs(now - 0.05) < 0.0001, 'variable frame duration was not retained');
delta, now = clock:step();
assert(math.abs(delta - 0.50) < 0.0001 and math.abs(now - 0.55) < 0.0001, 'low-FPS elapsed time was not retained');
delta, now = clock:step();
assert(math.abs(delta - 1.0) < 0.0001 and math.abs(now - 1.55) < 0.0001, 'one-second elapsed interval was not retained');
delta, now = clock:step();
assert(math.abs(delta - 100.0) < 0.0001 and math.abs(now - 101.55) < 0.0001, 'inactive-client elapsed interval was not retained');
delta, now = clock:step();
assert(delta == 0 and math.abs(now - 101.55) < 0.0001, 'backward clock movement must not roll alert time backward');

print('Timebase regression tests passed.');
