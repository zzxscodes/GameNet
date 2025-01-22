local game = require "game"
local redis = require "db.redis_proxy"
local mysql = require "db.mysql_proxy"
require "util"

local tab_concat = table.concat
local unpack = unpack

local hots = {}
local checks = {}

local _M = {}
local rds, mydb

local function remember_sql(template_func)
    return Remember(function (t, table)
        local schema = assert(hots[table])
        local sqlstr = template_func(schema, table)
        t[table] = sqlstr
        return sqlstr
    end)
end

local remember_insert_into = remember_sql(function(schema, table)
    local sql = {"insert into ", table, "("}
    local auto_inc = schema[1][2] == "ai"
    local fields = {}
    for i = auto_inc and 2 or 1, #schema do
        fields[#fields + 1] = schema[i][1]
    end
    sql[#sql + 1] = tab_concat(fields, ",")
    sql[#sql + 1] = ")"
    return tab_concat(sql)
end)

local remember_select_all_on_one_line = remember_sql(function(schema, table)
    return "select * from " .. table .. " where " .. schema[1][1] .. "="
end)

local function to_string(col, obj)
    if col[4] == "string" then
        return "'" .. (obj[col[1]] or col[3]) .. "'"
    end
    return obj[col[1]] or col[3]
end

local function values(table, obj)
    local schema = assert(hots[table])
    local auto_inc = schema[1][2] == "ai"
    local sql = {"values("}
    local data = {}
    for i = auto_inc and 2 or 1, #schema do
        data[#data + 1] = to_string(schema[i], obj)
    end
    sql[#sql + 1] = tab_concat(data, ',')
    sql[#sql + 1] = ")"
    return tab_concat(sql)
end

local function select_some_on_one_line(table, pk_value, ...)
    local schema = assert(hots[table])
    local sql = {"select ", tab_concat({...}, ","), " from ", table, " where ", schema[1][1], "=", pk_value}
    return mydb:query(tab_concat(sql))
end

local function to_string_by_type(typ, val)
    if typ == "string" then
        return "'" .. val .. "'"
    end
    return val
end

local function update_some_on_one_line(table, pk_value, kvs, inc)
    local chk = assert(checks[table])
    local schema = assert(hots[table])
    local sql = {"update ", table, " set "}
    local sets = {}
    for k, v in pairs(kvs) do
        local typ = assert(chk[k])
        if inc then
            sets[#sets + 1] = k .. "=" .. k .. (v > 0 and "+" or "") .. v
        else
            sets[#sets + 1] = k .. "=" .. to_string_by_type(typ, v)
        end
    end
    sql[#sql + 1] = tab_concat(sets, " ")
    sql[#sql + 1] = " where " .. schema[1][1] .. "=" .. pk_value
    local sqlstr = tab_concat(sql)
    print(sqlstr)
    return mydb:query(sqlstr)
end

local function hmget_some_field_on_one_key(table, pk_value, ...)
    local chk = assert(checks[table])
    local key = table .. ":" .. pk_value
    for _, field in ipairs({...}) do
        assert(chk[field])
    end
    return rds:hmget(key, ...)
end

function _M.init()
    local err
    rds, err = redis.instance("127.0.0.1", 6379)
    if not rds then
        print("failed to connect redis:", err)
        return
    end
    mydb, err = mysql.instance("127.0.0.1", 3306, {
        database = "practice",
        user = "debian-sys-maint",
        password = "YjjjR1FWtCEHNZ0Q",
    })
    if not mydb then
        print("failed to connect mysql:", err)
        return
    end
end

function _M.get_redis()
    return assert(rds)
end

function _M.get_mysql()
    return assert(mydb)
end

function _M.register(table, schema)
    if hots[table] then
        print("repeat register hots schema:", table)
    end
    hots[table] = schema
    local chk = {}
    for _, col in ipairs(schema) do
        chk[col[1]] = col[4]
    end
    checks[table] = chk
end

function _M.new_obj(table, obj)
    assert(mydb)
    local sqlstr = remember_insert_into[table] .. values(table, obj)
    print(sqlstr)
    return mydb:query(sqlstr)
end

function _M.get_obj(table, pk_value, ...)
    assert(rds and mydb, "please call init first")
    local n = select("#", ...)
    local res, err
    local exist = true
    local rds_key = table .. ":" .. pk_value
    if n == 0 then
        res, err = rds:hgetall(rds_key)
        exist = next(res) ~= nil
        print("try get data from redis ... ")
        if not res or not exist then
            print("try get data from mysql ... ")
            local sqlstr = remember_select_all_on_one_line[table] .. pk_value
            res, err = mydb:query(sqlstr)
            assert(res, err)
        end
    else
        res, err = hmget_some_field_on_one_key(table, pk_value, ...)
        exist = next(res) ~= nil
        print("try get data from redis ... ")
        if not res or not exist then
            print("try get data from mysql ... ")
            res, err = select_some_on_one_line(table, pk_value, ...)
            assert(res, err)
        end
    end
    if not exist then
        game.fork(function ()
            local kvs = {}
            for k, v in pairs(res[1]) do
                kvs[#kvs + 1] = k
                kvs[#kvs + 1] = v
            end
            rds:hmset(rds_key, unpack(kvs))
        end)
    end
    return res
end

function _M.set_obj(table, pk_value, kvs)
    assert(rds and mydb, "please call init first")
    local rds_key = table .. ":" .. pk_value
    local res, err = rds:del(rds_key)
    print("try set data to mysql ... ")
    res, err = update_some_on_one_line(table, pk_value, kvs, false)
    assert(res, err)
    return res
end

function _M.inc_obj(table, pk_value, kvs)
    assert(rds and mydb, "please call init first")
    local rds_key = table .. ":" .. pk_value
    local res, err = rds:del(rds_key)
    res, err = update_some_on_one_line(table, pk_value, kvs, true)
    assert(res, err)
    return res
end

function _M.del_obj(table, pk_value)
    assert(rds and mydb, "please call init first")
    local schema = assert(hots[table])
    local rds_key = table .. ":" .. pk_value
    local res, err = rds:del(rds_key)
    local sql = {"delete from ", table, " where ", schema[1][1], "=", pk_value}
    res, err = mydb:query(tab_concat(sql))
    assert(res, err)
    return res
end

-- -- Initialize the database cache
-- _M.init()

-- -- Register a table schema
-- _M.register("users", {
--     {"id", "ai", "int", "number"},
--     {"name", "string", "varchar(255)", "string"},
--     {"age", "int", "int", "number"}
-- })

-- -- Create a new object in the "users" table
-- _M.new_obj("users", {name = "John Doe", age = 30})

-- -- Get an object from the "users" table
-- local user = _M.get_obj("users", 1)
-- print(user)

-- -- Update an object in the "users" table
-- _M.set_obj("users", 1, {age = 31})

-- -- Increment a field in the "users" table
-- _M.inc_obj("users", 1, {age = 1})

-- -- Delete an object from the "users" table
-- _M.del_obj("users", 1)

return _M
