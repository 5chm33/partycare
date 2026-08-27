local Timebase = {};
Timebase.__index = Timebase;

-- PartyCare's alert timers must advance according to elapsed time, not frame
-- count.  The injected reader keeps the implementation deterministic in tests.
function Timebase.new(reader)
    return setmetatable({reader = reader or os.clock, last = nil, now = 0}, Timebase);
end

function Timebase:step()
    local observed = tonumber(self.reader());
    if observed == nil then return 0, self.now; end
    if self.last == nil then
        self.last = observed;
        return 0, self.now;
    end
    local delta = observed - self.last;
    self.last = observed;
    -- Clock adjustments must never move alerts backwards.  Large positive gaps
    -- intentionally advance time so expired buffs and stale enemy effects do
    -- not remain visible after an inactive client resumes rendering.
    if delta < 0 then delta = 0; end
    self.now = self.now + delta;
    return delta, self.now;
end

return Timebase;
