package.cpath = package.cpath..";./luaclib/pb.so;"
local pb = require "pb"
local protoc = require "protoc"

local protobuf = {}

-- 动态加载proto文件
function protobuf.load_proto(proto_content)
    local p = protoc.new()
    local result, err = p:load(proto_content)
    if not result then
        error("Failed to load proto: " .. err)
    end
end

function protobuf.serialize(message, message_type)
    local bytes, err = pb.encode(message_type, message)
    if not bytes then
        error("Failed to serialize message: " .. err)
    end
    return bytes
end

function protobuf.deserialize(buffer, message_type)
    local message, err = pb.decode(message_type, buffer)
    if not message then
        error("Failed to deserialize message: " .. err)
    end
    return message
end

-- Usage examples:
-- local proto_content = [[
-- syntax = "proto3";
-- message Person {
--   string name = 1;
--   int32 id = 2;
--   string email = 3;
-- }
-- ]]
-- protobuf.load_proto(proto_content)
-- local message = { name = "Alice", id = 123, email = "alice@example.com" }
-- local serialized = protobuf.serialize(message, "Person")
-- local deserialized = protobuf.deserialize(serialized, "Person")
-- print(deserialized.name)  -- Output: Alice

return protobuf
