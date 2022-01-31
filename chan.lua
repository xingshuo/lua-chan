local tremove = table.remove
local tinsert = table.insert

local assert = assert
local coroutine = coroutine

local ErrQueueFull = 'queue full'
local ErrQueueEmpty = 'channel queue empty'
local ErrChanClosed = 'channel closed'

local chan_mt = {}
chan_mt.__index = chan_mt

function chan_mt:init(cap)
    assert(cap > 0)
    self.m_RecvQ = { t = 0, h = 1, sz = 0, cap = cap }
    self.m_PushWaitingQ = {}
    self.m_PopWaitingQ = {}
    self.m_Closed = false
end

-- 返回值: true(成功) or false(失败), reason
function chan_mt:Push(v, noblocking)
    assert(not self.m_Closed, ErrChanClosed)
    if self.m_RecvQ.sz >= self.m_RecvQ.cap then
        if noblocking then
            return false, ErrQueueFull
        end

        local co = coroutine.running()
        tinsert(self.m_PushWaitingQ, co)
        coroutine.yield()
        if self.m_Closed then
            return false, ErrChanClosed
        end
        if self.m_RecvQ.sz >= self.m_RecvQ.cap then
            return false, ErrQueueFull
        end
    end

    local tail = self.m_RecvQ.t + 1
    if tail > self.m_RecvQ.cap then
        tail = 1
    end
    self.m_RecvQ.t = tail
    self.m_RecvQ[tail] = v
    self.m_RecvQ.sz = self.m_RecvQ.sz + 1

    if #self.m_PopWaitingQ > 0 then
        local co = tremove(self.m_PopWaitingQ, 1)
        coroutine.resume(co)
    end

    return true
end

-- 返回值: true(成功) or false(失败), reason
function chan_mt:Pop(noblocking)
    assert(not self.m_Closed, ErrChanClosed)
    if self.m_RecvQ.sz == 0 then
        if noblocking then
            return false, ErrQueueEmpty
        end

        local co = coroutine.running()
        tinsert(self.m_PopWaitingQ, co)
        coroutine.yield()
        if self.m_Closed then
            return false, ErrChanClosed
        end
        if self.m_RecvQ.sz == 0 then
            return false, ErrQueueEmpty
        end
    end

    local head = self.m_RecvQ.h
    local v = self.m_RecvQ[head]
    head = head + 1
    if head > self.m_RecvQ.cap then
        head = 1
    end
    self.m_RecvQ.h = head
    self.m_RecvQ.sz = self.m_RecvQ.sz - 1

    if #self.m_PushWaitingQ > 0 then
        local co = tremove(self.m_PushWaitingQ, 1)
        coroutine.resume(co)
    end

    return true, v
end

function chan_mt:Size()
    return self.m_RecvQ.sz
end

function chan_mt:__pairs()
    return function ()
        if self.m_Closed then
            return
        end
        local ok, v  = self:Pop()
        if not ok and v == ErrChanClosed then
            return
        end
        return ok, v
    end
end

function chan_mt:Close()
    if self.m_Closed then
        return false
    end

    self.m_Closed = true
    for _, co in pairs(self.m_PushWaitingQ) do
        coroutine.resume(co)
    end
    for _, co in pairs(self.m_PopWaitingQ) do
        coroutine.resume(co)
    end

    return true
end

-- create channel function
return function (cap)
    local c = {}
    setmetatable(c, chan_mt)
    c:init(cap)
    return c
end