package.cpath = package.cpath..";./luaclib/?.so;"
package.path = package.path .. ";./lualib/?.lua;"

local socket = require "socket"
local evloop = require "evloop"
local config = require "configure"

local clients = {}
local chatservers = {}
local current_server = 1

local function connect_chatservers()
    for _, port in ipairs(config.chatserver_ports) do
        local serverfd, err = socket.block_connect("127.0.0.1", port)
        if serverfd ~= -1 then
            table.insert(chatservers, serverfd)
            socket.bind(serverfd, server_loop)
        else
            print("block_connect 127.0.0.1:" .. port .. " error:", err)
        end
    end
end

local function client_loop(fd)
    while true do
        local buf, err = socket.readline(fd, "\n")
        if err then
            print("error", err)
            socket.close(fd)
            clients[fd] = nil
            return
        end
        print("recv from client:", buf)
        local serverfd = chatservers[current_server]
        current_server = (current_server % #chatservers) + 1
        socket.write(serverfd, buf .. "\n")
    end
end

local function server_loop(fd)
    while true do
        local buf, err = socket.readline(fd, "\n")
        if err then
            print("error", err)
            socket.close(fd)
            return
        end
        print("recv from server:", buf)
        -- Forward to all connected clients
        for clientfd, _ in pairs(clients) do
            socket.write(clientfd, buf .. "\n")
        end
    end
end

evloop.start("0.0.0.0:" .. config.gateway_port, function (fd, ip, port)
    print("accept a connection:", fd, ip, port)
    clients[fd] = true
    socket.bind(fd, client_loop)
end)

connect_chatservers()
evloop.run()
