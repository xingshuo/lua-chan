local Chan = require 'chan'

local assert = assert
local sformat = string.format

function printf(...)
    print(sformat(...))
end

function test1()
    local c = Chan(3)
    local msg_list = {100, 200, 300}

    local producer = coroutine.wrap(function ()
        for _, msg in ipairs(msg_list) do
            assert(c:Push(msg))
        end
        assert(not c:Push(400, true) and c:Size() == 3)
        printf('producer push blocked')
        c:Push(500)
        printf('producer push done')
    end)

    local consumer = coroutine.wrap(function()
        for _, msg in ipairs(msg_list) do
            local ok, v = c:Pop()
            assert(ok and v == msg)
            printf('consumer pop %s', v)
        end
        local ok, v = c:Pop()
        assert(ok and v == 500)
        assert(c:Size() == 0, c:Size())
        ok = c:Pop(true)
        assert(not ok)
    end)

    producer()
    consumer()
end


test1()