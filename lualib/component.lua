local socket = require("socket")
local ffi = require("ffi")
local coroutine = require("coroutine")

ffi.cdef[[
    typedef struct FILE FILE;
    FILE *fopen(const char *filename, const char *mode);
    int fprintf(FILE *stream, const char *format, ...);
    int fclose(FILE *stream);
    char *fgets(char *str, int n, FILE *stream);
    size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
    int fseek(FILE *stream, long offset, int whence);
    long ftell(FILE *stream);
]]

-- Logger component
local Logger = {}
Logger.__index = Logger

function Logger:new(logFilePath)
    local instance = {
        logs = {},
        logFilePath = logFilePath,
        logLevels = { "DEBUG", "INFO", "WARN", "ERROR" },
        currentLevel = "DEBUG",
        logQueue = {},
        isWriting = false,
        co = nil
    }
    setmetatable(instance, Logger)
    return instance
end

function Logger:setLevel(level)
    self.currentLevel = level
end

function Logger:log(level, message)
    if self:_shouldLog(level) then
        local logMessage = string.format("[%s] [%s]: %s", os.date("%Y-%m-%d %H:%M:%S"), level, message)
        table.insert(self.logs, logMessage)
        print(logMessage)
        if self.logFilePath then
            table.insert(self.logQueue, logMessage)
            self:_writeLogAsync()
        end
    end
end

function Logger:_shouldLog(level)
    local levelIndex = self:_getLevelIndex(level)
    local currentLevelIndex = self:_getLevelIndex(self.currentLevel)
    return levelIndex >= currentLevelIndex
end

function Logger:_getLevelIndex(level)
    for i, v in ipairs(self.logLevels) do
        if v == level then
            return i
        end
    end
    return #self.logLevels
end

function Logger:_writeLogAsync()
    if not self.isWriting and #self.logQueue > 0 then
        self.isWriting = true
        self.co = coroutine.create(function()
            while #self.logQueue > 0 do
                local logMessage = table.remove(self.logQueue, 1)
                local file = ffi.C.fopen(self.logFilePath, "a")
                if file ~= nil then
                    ffi.C.fprintf(file, "%s\n", logMessage)
                    ffi.C.fclose(file)
                end
                coroutine.yield()
            end
            self.isWriting = false
        end)
        coroutine.resume(self.co)
    elseif self.co and coroutine.status(self.co) == "suspended" then
        coroutine.resume(self.co)
    end
end

-- Configuration Loader component
local ConfigLoader = {}
ConfigLoader.__index = ConfigLoader

function ConfigLoader:new()
    local instance = {
        config = {}
    }
    setmetatable(instance, ConfigLoader)
    return instance
end

function ConfigLoader:load(filePath)
    local file = ffi.C.fopen(filePath, "r")
    if file == nil then
        error("Could not open config file: " .. filePath)
    end

    ffi.C.fseek(file, 0, 2) -- SEEK_END
    local size = ffi.C.ftell(file)
    ffi.C.fseek(file, 0, 0) -- SEEK_SET

    local buffer = ffi.new("char[?]", size + 1)
    ffi.C.fread(buffer, 1, size, file)
    ffi.C.fclose(file)

    local content = ffi.string(buffer, size)
    self.config = assert(load("return " .. content))()
end

function ConfigLoader:get(key)
    return self.config[key]
end

-- Example config file (config.lua):
-- return {
--     key1 = "value1",
--     key2 = "value2",
--     nested = {
--         key3 = "value3"
--     }
-- }

-- Event Manager component
local EventManager = {}
EventManager.__index = EventManager

function EventManager:new()
    local instance = {
        listeners = {}
    }
    setmetatable(instance, EventManager)
    return instance
end

-- 注册事件监听器
function EventManager:on(event, listener)
    if type(event) ~= "string" or type(listener) ~= "function" then
        error("Invalid event or listener")
    end
    if not self.listeners[event] then
        self.listeners[event] = {}
    end
    table.insert(self.listeners[event], listener)
end

-- 触发事件
function EventManager:emit(event, ...)
    if type(event) ~= "string" then
        error("Invalid event")
    end
    if self.listeners[event] then
        for _, listener in ipairs(self.listeners[event]) do
            local ok, err = pcall(listener, ...)
            if not ok then
                print("Error in event listener:", err)
            end
        end
    end
end

-- Example of registering an event listener:
-- local eventManager = EventManager:new()
-- eventManager:on("eventName", function(arg1, arg2)
--     print("Event triggered with arguments:", arg1, arg2)
-- end)

-- Example of emitting an event:
-- eventManager:emit("eventName", "arg1", "arg2")

-- Export components
return {
    Logger = Logger,
    ConfigLoader = ConfigLoader,
    EventManager = EventManager
}