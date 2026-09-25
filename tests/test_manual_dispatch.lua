package.path = './?.lua;./?/init.lua;' .. package.path

local Adapter = require('src.manual_dispatch_adapter')

local function assert_equal(actual, expected, message)
    if actual ~= expected then error((message or 'assertion failed') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual), 2) end
end
local function assert_match(value, pattern, message)
    if type(value) ~= 'string' or not value:match(pattern) then error(message or ('value did not match ' .. pattern), 2) end
end
local function assert_rejected(dispatch, expected, message)
    local ok, reason = dispatch()
    assert_equal(ok, false, message)
    assert_equal(reason, expected, message)
end

local function intent(slot, spell)
    return {kind = 'MANUAL_CLICK_CAST_REQUEST', sequence = 1, party_slot = slot, spell = spell, member_name = 'Synthetic'}
end

-- Target mapping is checked without an Ashita client or a live cast.
assert_equal(Adapter.build_command(intent(0, 'Cure IV')), '/ma "Cure IV" <p0>')
assert_equal(Adapter.build_command(intent(5, 'Cure IV')), '/ma "Cure IV" <p5>')
assert_equal(Adapter.build_command(intent(6, 'Cure IV')), '/ma "Cure IV" <a10>')
assert_equal(Adapter.build_command(intent(11, 'Cure IV')), '/ma "Cure IV" <a15>')
assert_equal(Adapter.build_command(intent(12, 'Cure IV')), '/ma "Cure IV" <a20>')
assert_equal(Adapter.build_command(intent(17, 'Cure IV')), '/ma "Cure IV" <a25>')

local manager = {calls = {}}
function manager:QueueCommand(channel, command) table.insert(self.calls, {channel = channel, command = command}) end
local adapter = Adapter.new(manager)

assert_rejected(function() return adapter:dispatch(intent(0, 'Cure IV'), {manual_dispatch_enabled = false}) end, 'manual dispatch is disabled')
assert_rejected(function() return adapter:dispatch(intent(0, 'Cure IV'), {manual_dispatch_enabled = true, emergency_stop = true}) end, 'emergency stop is active')
assert_rejected(function() return adapter:dispatch(intent(0, 'Cure " IV'), {manual_dispatch_enabled = true, emergency_stop = false}) end, 'spell contains unsupported characters')
assert_equal(#manager.calls, 0, 'gated requests must not queue commands')

local ok, command = adapter:dispatch(intent(6, 'Cure IV'), {manual_dispatch_enabled = true, emergency_stop = false})
assert_equal(ok, true)
assert_equal(command, '/ma "Cure IV" <a10>')
assert_equal(#manager.calls, 1)
assert_equal(manager.calls[1].channel, 1)
assert_equal(manager.calls[1].command, command)
assert_equal(#adapter:drain_audit(), 1)

print('manual dispatch offline tests: PASS (synthetic chat manager; no live casts)')
