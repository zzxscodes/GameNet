local dhash = require "gamenet.dhash"

local Route = {}
Route.__index = Route

-- Create a new Route instance with a specified size
function Route:new(size)
    local self = setmetatable({}, Route)
    self.dhash_table = dhash.new(size)
    self.current_index = 0
    return self
end

-- Add a route to the hash table
function Route:add_route(key, value)
    local result = self.dhash_table:insert(key, value)
    if result ~= 0 then
        error("Failed to add route")
    end
end

-- Remove a route from the hash table
function Route:remove_route(key)
    local result = self.dhash_table:delete(key)
    if result ~= 0 then
        error("Failed to remove route")
    end
end

-- Find a route in the hash table
function Route:find_route(key)
    local value = self.dhash_table:search(key)
    if value == nil then
        return nil
    else
        return value
    end
end

-- Update an existing route with a new value
function Route:update_route(key, new_value)
    self:remove_route(key)
    self:add_route(key, new_value)
end

-- List all routes in the hash table
function Route:list_routes()
    local routes = {}
    for i = 0, self.dhash_table.max_size - 1 do
        local node = self.dhash_table.nodes[i]
        if node then
            routes[node.key] = node.value
        end
    end
    return routes
end

-- Balance the load by selecting the next route in a round-robin fashion
function Route:balance_route()
    local routes = self:list_routes()
    local keys = {}
    for key in pairs(routes) do
        table.insert(keys, key)
    end
    if #keys == 0 then
        return nil
    end
    self.current_index = (self.current_index or 0) % #keys + 1
    return routes[keys[self.current_index]]
end

-- Discover services by name
function Route:discover_service(service_name)
    local routes = self:list_routes()
    local services = {}
    for key, value in pairs(routes) do
        if value.service == service_name then
            table.insert(services, value)
        end
    end
    return services
end

-- Forward a request to a service
function Route:forward_request(service_name, request)
    local services = self:discover_service(service_name)
    if #services == 0 then
        error("No available service to forward request")
    end
    self.current_index = (self.current_index or 0) % #services + 1
    local service = services[self.current_index]
    if service and service.handle_request then
        return service:handle_request(request)
    else
        error("Selected service cannot handle request")
    end
end

-- Destroy the route table
function Route:destroy()
    local result = self.dhash_table:destroy()
    if result ~= 0 then
        error("Failed to destroy route table")
    end
end

return Route

-- Usage example:
-- local route = Route:new(10)
-- route:add_route("service1", {service = "example_service", handle_request = function(req) return "response" end})
-- local response = route:forward_request("example_service", "request")
-- print(response)  -- Output: "response"
-- route:destroy()

