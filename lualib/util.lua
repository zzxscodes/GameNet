-- Function to recursively dump the contents of a table into a string
local function table_dump(object)
    if type(object) == 'table' then
        local s = '{ '
        for k, v in pairs(object) do
            if type(k) ~= 'number' then k = string.format("%q", k) end
            s = s .. '[' .. k .. '] = ' .. table.dump(v) .. ','
        end
        return s .. '} '
    elseif type(object) == 'function' then
        return tostring(object)
    elseif type(object) == 'string' then
        return string.format("%q", object)
    else
        return tostring(object)
    end
end

-- Function to copy a table
local function table_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table_copy(orig_key)] = table_copy(orig_value)
        end
        setmetatable(copy, table_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Function to merge two tables
local function table_merge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k] or false) == "table" then
            table_merge(t1[k], v)
        else
            t1[k] = v
        end
    end
    return t1
end

-- Function to get the length of a table
local function table_length(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- Function to split a string by a given delimiter
local function string_split(input, delimiter)
    local result = {}
    for match in (input .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

-- Function to trim whitespace from both ends of a string
local function string_trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Function to create a table with weak keys and values, and a default function for missing keys
function Remember(func)
    return setmetatable({}, {
        __mode = "kv",  -- Weak keys and values
        __index = func, -- Default function for missing keys
    })
end

table.dump = table_dump
table.copy = table_copy
table.merge = table_merge
table.length = table_length
string.split = string_split
string.trim = string_trim