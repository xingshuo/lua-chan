local Chan = require 'chan'

local assert = assert
local sformat = string.format

function printf(...)
    print(sformat(...))
end

function test_1p1c()
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

function test_2p1c()
    local c = Chan(1)
    local producer1 = coroutine.wrap(function ()
        for i = 1, 5 do
            printf('producer1 start push <%s>',  2*i)
            local ok, err = c:Push(2*i)
            if not ok then
                printf('producer1 push <%s> failed, %s', 2*i, err)
                break
            end
            printf('producer1 push <%s> done', 2*i)
        end

        printf('producer1 start close chan')
        assert(c:Close())
        printf('producer1 close chan done')
    end)

    local producer2 = coroutine.wrap(function ()
        for i = 1, 5 do
            printf('producer2 start push <%s>',  2*i - 1)
            local ok, err = c:Push(2*i - 1)
            if not ok then
                printf('producer2 push <%s> failed, %s', 2*i - 1, err)
                break
            end
            printf('producer2 push <%s> done', 2*i - 1)
        end

        printf('producer2 start close chan')
        assert(not c:Close())
        printf('producer2 close chan done')
    end)

    local consumer1 = coroutine.wrap(function()
        for ok, v in pairs(c) do
            printf('consumer1 get %s, %s', ok, v)
        end
        printf('consumer1 quit chan')
    end)

    producer1()
    producer2()
    consumer1()
end

function test_1p2c()
    local c = Chan(1)
    local producer1 = coroutine.wrap(function ()
        for i = 1, 5 do
            printf('producer1 start push <%s>',  2*i)
            local ok, err = c:Push(2*i)
            if not ok then
                printf('producer1 push <%s> failed, %s', 2*i, err)
                break
            end
            printf('producer1 push <%s> done', 2*i)
        end

        printf('producer1 start close chan')
        assert(c:Close())
        printf('producer1 close chan done')
    end)

    local consumer1 = coroutine.wrap(function()
        for ok, v in pairs(c) do
            printf('consumer1 get %s, %s', ok, v)
        end
        printf('consumer1 quit chan')
    end)

    local consumer2 = coroutine.wrap(function()
        for ok, v in pairs(c) do
            printf('consumer2 get %s, %s', ok, v)
        end
        printf('consumer2 quit chan')
    end)

    consumer1()
    consumer2()
    producer1()
end

printf('----one producer and one consumer test begin.----')
test_1p1c()

printf('----two producer and one consumer test begin.----')
test_2p1c()

printf('----one producer and two consumer test begin.----')
test_1p2c()

printf('----all test done!-----')