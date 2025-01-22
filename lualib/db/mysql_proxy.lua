local game = require "game"
local mysql = require "db.mysql"
local socket = require "socket"

local db = false
local disconnected = true
local proxy = {}
local backlog = {}
local _M = {}
local tab_remove = table.remove

local function handle_result(res, err, errno, sqlstate)
    if not res then
        local badresult = {badresult = true, err = err, errno = errno, sqlstate = sqlstate}
        local co = tab_remove(backlog, 1)
        game.co_resume(co, res, badresult)
    else
        if err ~= "again" then
            local co = tab_remove(backlog, 1)
            game.co_resume(co, res, err)
        else
            local mres = {res, multiresultset = true}
            local i = 2
            while err == "again" do
                res, err, errno, sqlstate = db:read_result()
                if not res then
                    mres.badresult = true
                    mres.err = err
                    mres.errno = errno
                    mres.sqlstate = sqlstate
                    local co = tab_remove(backlog, 1)
                    game.co_resume(co, nil, mres)
                    break
                end
                mres[i] = res
                i = i + 1
            end
            if not mres.badresult then
                local co = tab_remove(backlog, 1)
                game.co_resume(co, mres)
            end
        end
    end
end

local function mysql_eventloop()
    assert(db)
    local fd = assert(db.sock)
    socket.rebind(fd)
    while true do
        local res, err, errno, sqlstate = db:read_result()
        handle_result(res, err, errno, sqlstate)
    end
end

local function new(...)
    assert(false, "please use `instance` interface instead of `new` in proxy mode")
end

local function set_keepalive(...)
    assert(false, "cant use `set_keepalive` in proxy mode")
end

local function read_result(...)
    assert(false, "cant use `read_result` in proxy mode")
end

local function send_query(...)
    assert(false, "cant use `send_query` in proxy mode")
end

local function proxy_metafunc(tab, cmd)
    local function wait_for_response(self, ...)
        if cmd == "query" then
            cmd = "send_query"
        end
        local res, err = self[1][cmd](self[1], ...)
        if res then
            backlog[#backlog+1] = game.co_running()
            local fd = self[1].sock
            game.co_attach(fd)
            res, err = game.co_yield()
            game.co_detach(fd)
        end
        return res, err
    end
    tab[cmd] = wait_for_response
    return wait_for_response
end

local function instance(host, port, opts)
    if not db then
        local connecting = true
        local err
        db, err = mysql.new(host, port, {
            database = opts.database,
            user = opts.user,
            password = opts.password,
            charset = opts.charset,
            max_packet_size = opts.max_packet_size,
            compact_arrays = opts.compact_arrays,
            proxy = true,
        })
        assert(db, err)
        connecting = false
        local fd = assert(db.sock)
        disconnected = false
        socket.onclose(fd, function (_)
            disconnected = true
            socket.close(fd)
            for _, co in ipairs(backlog) do
                game.co_resume(co, nil, "closed")
            end
            backlog = {}
            setmetatable(proxy, {
                __index = function (_, cmd)
                    return function (_, ...)
                        if disconnected and connecting then
                            return nil, "db is connecting"
                        end
                        print("try reconnect mysql ...")
                        db = false
                        proxy = instance(host, port, opts)
                        return proxy[cmd](proxy, ...)
                    end
                end
            })
        end)
        proxy = setmetatable({db,
                new = new,
                set_keepalive = set_keepalive,
                read_result = read_result,
                send_query = send_query,
            },{__index = proxy_metafunc})
        game.fork(mysql_eventloop)
    end
    return proxy
end

_M.instance = instance

return _M
