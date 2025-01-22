package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local socket = require "socket"
local evloop = require "evloop"
local config = require "configure"

local clients = {}

local function broadcast(message)
    for fd, _ in pairs(clients) do
        socket.write(fd, message .. "\n")
    end
end

local function client_loop(fd)
    clients[fd] = true
    while true do
        local buf, err = socket.readline(fd, "\n")
        if err then
            print("error", err)
            socket.close(fd)
            clients[fd] = nil
            return
        end
        print("recv from client:", buf)
        broadcast(buf)
        socket.write(fd, buf .. "\n")  -- Send back the original string to the gateway
    end
end

evloop.start("0.0.0.0:" .. config.chatserver_ports, function (fd, ip, port)
    print("accept a connection:", fd, ip, port)
    socket.bind(fd, client_loop)
end)

evloop.run()
