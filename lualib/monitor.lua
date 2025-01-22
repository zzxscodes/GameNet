local ffi = require("ffi")
local socket = require("socket")
local Logger = require("component").Logger
local EventManager = require("component").EventManager
local ConfigLoader = require("component").ConfigLoader

ffi.cdef[[
    typedef struct {
        long tv_sec;
        long tv_usec;
    } timeval;

    int gettimeofday(struct timeval *tv, struct timezone *tz);
]]

local Monitor = {}
Monitor.__index = Monitor

function Monitor:new(logFilePath, configFilePath, serverAddress, serverPort)
    local instance = {
        logger = Logger:new(logFilePath),
        eventManager = EventManager:new(),
        configLoader = ConfigLoader:new(),
        startTime = ffi.new("struct timeval"),
        endTime = ffi.new("struct timeval"),
        serverAddress = serverAddress,
        serverPort = serverPort,
        clientSocket = nil,
        serverSocket = nil,
        clientSockets = {}
    }
    instance.configLoader:load(configFilePath)
    setmetatable(instance, Monitor)
    return instance
end

function Monitor:start()
    ffi.C.gettimeofday(self.startTime, nil)
    self.logger:log("INFO", "Monitoring started")
    self.clientSocket = assert(socket.connect(self.serverAddress, self.serverPort))
    self.clientSocket:settimeout(0)
end

function Monitor:stop()
    ffi.C.gettimeofday(self.endTime, nil)
    local elapsedTime = (self.endTime.tv_sec - self.startTime.tv_sec) * 1000.0 + (self.endTime.tv_usec - self.startTime.tv_usec) / 1000.0
    self.logger:log("INFO", string.format("Monitoring stopped. Elapsed time: %.2f ms", elapsedTime))
    if self.clientSocket then
        self.clientSocket:close()
    end
    if self.serverSocket then
        self.serverSocket:close()
    end
end

function Monitor:logEvent(event, ...)
    self.eventManager:emit(event, ...)
    self.logger:log("DEBUG", string.format("Event '%s' triggered", event))
end

function Monitor:getConfig(key)
    return self.configLoader:get(key)
end

function Monitor:collectServerInfo()
    if self.clientSocket then
        self.clientSocket:send("GET /performance\n")
        local response, err = self.clientSocket:receive()
        if not err then
            self.logger:log("INFO", "Server performance info: " .. response)
        else
            self.logger:log("ERROR", "Failed to collect server info: " .. err)
        end
    else
        self.logger:log("ERROR", "Client socket is not connected")
    end
end

function Monitor:startServer()
    self.serverSocket = assert(socket.bind("*", self.serverPort))
    self.serverSocket:settimeout(0)
    self.logger:log("INFO", "Server started on port " .. self.serverPort)
    while true do
        local client = self.serverSocket:accept()
        if client then
            client:settimeout(0)
            table.insert(self.clientSockets, client)
            self.logger:log("INFO", "Client connected")
        end
        for i, client in ipairs(self.clientSockets) do
            local request, err = client:receive()
            if not err then
                self:handleRequest(client, request)
            elseif err == "closed" then
                table.remove(self.clientSockets, i)
                self.logger:log("INFO", "Client disconnected")
            end
        end
        socket.sleep(0.01)
    end
end

function Monitor:handleRequest(client, request)
    if request == "GET /performance" then
        local response = self:collectPerformanceInfo()
        client:send(response .. "\n")
    else
        client:send("Unknown request\n")
    end
end

function Monitor:collectPerformanceInfo()
    local commands = {
        cpu = "top -bn1 | grep 'Cpu(s)'",
        memory = "free -m",
        disk = "df -h",
        network = "ifstat 1 1"
    }
    local results = {}
    for key, cmd in pairs(commands) do
        local handle = io.popen(cmd)
        local result = handle:read("*a")
        handle:close()
        results[key] = result
    end
    return table.concat(results, "\n")
end

return Monitor

-- Usage example for server:
-- local Monitor = require("monitor")
-- local serverMonitor = Monitor:new("server.log", "config.lua", "localhost", 12345)
-- serverMonitor:startServer()

-- Usage example for client:
-- local Monitor = require("monitor")
-- local clientMonitor = Monitor:new("client.log", "config.lua", "localhost", 12345)
-- clientMonitor:start()
-- clientMonitor:collectServerInfo()
-- clientMonitor:stop()
