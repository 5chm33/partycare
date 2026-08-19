local Util = require('src.util');

local ReviewAdapter = {};
ReviewAdapter.__index = ReviewAdapter;

function ReviewAdapter.new()
    return setmetatable({requests = {}, rejected = {}}, ReviewAdapter);
end

function ReviewAdapter:accept(intent, approval_status)
    if type(intent) ~= 'table' or intent.kind ~= 'MANUAL_CLICK_CAST_REQUEST' then
        return false, 'unsupported intent';
    end
    if approval_status ~= 'HORIZONXI_APPROVED' then
        table.insert(self.rejected, {intent = Util.copy(intent), reason = 'approval status is not HORIZONXI_APPROVED'});
        return false, 'click-cast execution remains disabled pending HorizonXI approval';
    end
    -- This review candidate deliberately has no executor. Approval only changes the audit classification.
    table.insert(self.requests, {intent = Util.copy(intent), reviewed_at = intent.at});
    return false, 'no execution adapter is included in the review candidate';
end

function ReviewAdapter:drain()
    local requests, rejected = Util.copy(self.requests), Util.copy(self.rejected);
    self.requests, self.rejected = {}, {};
    return requests, rejected;
end

return ReviewAdapter;
