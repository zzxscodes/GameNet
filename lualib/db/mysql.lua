local core = require "gamenet.core"
local socket = require "socket"
local read = socket.read
local send = socket.write

local bit = require "bit"
local sub = string.sub
local strbyte = string.byte
local strchar = string.char
local strfind = string.find
local format = string.format
local strrep = string.rep
local band = bit.band
local bxor = bit.bxor
local bor = bit.bor
local lshift = bit.lshift
local rshift = bit.rshift
local tohex = bit.tohex
local sha1 = core.sha1
local concat = table.concat
local setmetatable = setmetatable
local error = error
local tonumber = tonumber
local to_int = math.floor
local new_tab = require "table.new"

local _M = { _VERSION = '0.24' }

local STATE_CONNECTED = 1
local STATE_COMMAND_SENT = 2
local COM_QUIT = 0x01
local COM_QUERY = 0x03
local DEFAULT_CLIENT_FLAGS = 0x3f7cf
local CLIENT_SSL = 0x00000800
local CLIENT_PLUGIN_AUTH = 0x00080000
local CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA = 0x00200000
local SERVER_MORE_RESULTS_EXISTS = 8
local RESP_OK = "OK"
local RESP_AUTHMOREDATA = "AUTHMOREDATA"
local RESP_LOCALINFILE = "LOCALINFILE"
local RESP_EOF = "EOF"
local RESP_ERR = "ERR"
local RESP_DATA = "DATA"
local MY_RND_MAX_VAL = 0x3FFFFFFF
local MIN_PROTOCOL_VER = 10
local LEN_NATIVE_SCRAMBLE = 20
local LEN_OLD_SCRAMBLE = 8
local FULL_PACKET_SIZE = 16777215 -- 16MB - 1, the default max allowed packet size used by libmysqlclient

-- the following charset map is generated from the following mysql query:
--   SELECT CHARACTER_SET_NAME, ID
--   FROM information_schema.collations
--   WHERE IS_DEFAULT = 'Yes' ORDER BY id;
local CHARSET_MAP = {
    _default  = 0,
    big5      = 1,
    dec8      = 3,
    cp850     = 4,
    hp8       = 6,
    koi8r     = 7,
    latin1    = 8,
    latin2    = 9,
    swe7      = 10,
    ascii     = 11,
    ujis      = 12,
    sjis      = 13,
    hebrew    = 16,
    tis620    = 18,
    euckr     = 19,
    koi8u     = 22,
    gb2312    = 24,
    greek     = 25,
    cp1250    = 26,
    gbk       = 28,
    latin5    = 30,
    armscii8  = 32,
    utf8      = 33,
    ucs2      = 35,
    cp866     = 36,
    keybcs2   = 37,
    macce     = 38,
    macroman  = 39,
    cp852     = 40,
    latin7    = 41,
    utf8mb4   = 45,
    cp1251    = 51,
    utf16     = 54,
    utf16le   = 56,
    cp1256    = 57,
    cp1257    = 59,
    utf32     = 60,
    binary    = 63,
    geostd8   = 92,
    cp932     = 95,
    eucjpms   = 97,
    gb18030   = 248
}

local mt = { __index = _M }

-- mysql field value type converters
local converters = new_tab(0, 9)

for i = 0x01, 0x05 do
    -- tiny, short, long, float, double
    converters[i] = tonumber
end
converters[0x00] = tonumber  -- decimal
-- converters[0x08] = tonumber  -- long long
converters[0x09] = tonumber  -- int24
converters[0x0d] = tonumber  -- year
converters[0xf6] = tonumber  -- newdecimal


local function _get_byte2(data, i)
    local a, b = strbyte(data, i, i + 1)
    return bor(a, lshift(b, 8)), i + 2
end

local function _get_byte3(data, i)
    local a, b, c = strbyte(data, i, i + 2)
    return bor(a, lshift(b, 8), lshift(c, 16)), i + 3
end

local function _get_byte4(data, i)
    local a, b, c, d = strbyte(data, i, i + 3)
    return bor(a, lshift(b, 8), lshift(c, 16), lshift(d, 24)), i + 4
end

local function _get_byte8(data, i)
    local a, b, c, d, e, f, g, h = strbyte(data, i, i + 7)
    local lo = bor(a, lshift(b, 8), lshift(c, 16))
    local hi = bor(e, lshift(f, 8), lshift(g, 16), lshift(h, 24))
    return lo + 16777216 * d + hi * 4294967296, i + 8

end

local function _set_byte2(n)
    return strchar(band(n, 0xff), band(rshift(n, 8), 0xff))
end

local function _set_byte3(n)
    return strchar(band(n, 0xff),
                   band(rshift(n, 8), 0xff),
                   band(rshift(n, 16), 0xff))
end

local function _set_byte4(n)
    return strchar(band(n, 0xff),
                   band(rshift(n, 8), 0xff),
                   band(rshift(n, 16), 0xff),
                   band(rshift(n, 24), 0xff))
end

local function _from_cstring(data, i)
    local last = strfind(data, "\0", i, true)
    if not last then
        return nil, nil
    end

    return sub(data, i, last - 1), last + 1
end

local function _to_cstring(data)
    return data .. "\0"
end

local function _dump(data)
    local len = #data
    local bytes = new_tab(len, 0)
    for i = 1, len do
        bytes[i] = format("%x", strbyte(data, i))
    end
    return concat(bytes, " ")
end

local function _dumphex(data)
    local len = #data
    local bytes = new_tab(len, 0)
    for i = 1, len do
        bytes[i] = tohex(strbyte(data, i), 2)
    end
    return concat(bytes, " ")
end

local function _random_byte(seed1, seed2)
    seed1 = (seed1 * 3 + seed2) % MY_RND_MAX_VAL
    seed2 = (seed1 + seed2 + 33) % MY_RND_MAX_VAL

    return to_int(seed1 * 31 / MY_RND_MAX_VAL), seed1, seed2
end

local function _compute_token(password, scramble)
    if password == "" then
        return ""
    end

    scramble = sub(scramble, 1, LEN_NATIVE_SCRAMBLE)

    local stage1 = sha1(password)
    local stage2 = sha1(stage1)
    local stage3 = sha1(scramble .. stage2)
    local n = #stage1
    local bytes = new_tab(n, 0)
    for i = 1, n do
        bytes[i] = strchar(bxor(strbyte(stage3, i), strbyte(stage1, i)))
    end

    return concat(bytes)
end


local function _send_packet(self, req, size)
    local sock = self.sock

    self.packet_no = self.packet_no + 1

    local packet = _set_byte3(size) .. strchar(band(self.packet_no, 255)) .. req

    return send(sock, packet)
end

local function _recv_packet(self)
    local sock = self.sock

    local data, err = read(sock, 4) -- packet header
    if not data then
        return nil, nil, "failed to receive packet header: " .. err
    end

    local len, pos = _get_byte3(data, 1)

    if len == 0 then
        return nil, nil, "empty packet"
    end

    if len > self._max_packet_size then
        return nil, nil, "packet size too big: " .. len
    end

    local num = strbyte(data, pos)

    self.packet_no = num

    data, err = read(sock, len)

    if not data then
        return nil, nil, "failed to read packet content: " .. err
    end

    local field_count = strbyte(data, 1)

    local typ
    if field_count == 0x00 then
        typ = RESP_OK
    elseif field_count == 0x01 then
        typ = RESP_AUTHMOREDATA
    elseif field_count == 0xfb then
        typ = RESP_LOCALINFILE
    elseif field_count == 0xfe then
        typ = RESP_EOF
    elseif field_count == 0xff then
        typ = RESP_ERR
    else
        typ = RESP_DATA
    end

    return data, typ
end

local function _from_length_coded_bin(data, pos)
    local first = strbyte(data, pos)

    if not first then
        return nil, pos
    end

    if first >= 0 and first <= 250 then
        return first, pos + 1
    end

    if first == 251 then
        return null, pos + 1
    end

    if first == 252 then
        pos = pos + 1
        return _get_byte2(data, pos)
    end

    if first == 253 then
        pos = pos + 1
        return _get_byte3(data, pos)
    end

    if first == 254 then
        pos = pos + 1
        return _get_byte8(data, pos)
    end

    return nil, pos + 1
end

local function _from_length_coded_str(data, pos)
    local len
    len, pos = _from_length_coded_bin(data, pos)
    if not len or len == null then
        return null, pos
    end

    return sub(data, pos, pos + len - 1), pos + len
end

local function _parse_ok_packet(packet)
    local res = new_tab(0, 5)
    local pos

    res.affected_rows, pos = _from_length_coded_bin(packet, 2)

    res.insert_id, pos = _from_length_coded_bin(packet, pos)

    res.server_status, pos = _get_byte2(packet, pos)

    res.warning_count, pos = _get_byte2(packet, pos)

    local message = _from_length_coded_str(packet, pos)
    if message and message ~= null then
        res.message = message
    end

    return res
end

local function _parse_eof_packet(packet)
    local pos = 2

    local warning_count, pos = _get_byte2(packet, pos)
    local status_flags = _get_byte2(packet, pos)

    return warning_count, status_flags
end

local function _parse_err_packet(packet)
    local errno, pos = _get_byte2(packet, 2)
    local marker = sub(packet, pos, pos)
    local sqlstate
    if marker == '#' then
        -- with sqlstate
        pos = pos + 1
        sqlstate = sub(packet, pos, pos + 5 - 1)
        pos = pos + 5
    end

    local message = sub(packet, pos)
    return errno, message, sqlstate
end

local function _parse_result_set_header_packet(packet)
    local field_count, pos = _from_length_coded_bin(packet, 1)

    local extra
    extra = _from_length_coded_bin(packet, pos)

    return field_count, extra
end

local function _parse_field_packet(data)
    local col = new_tab(0, 2)
    local catalog, db, table, orig_table, orig_name, charsetnr, length
    local pos
    catalog, pos = _from_length_coded_str(data, 1)

    db, pos = _from_length_coded_str(data, pos)
    table, pos = _from_length_coded_str(data, pos)
    orig_table, pos = _from_length_coded_str(data, pos)
    col.name, pos = _from_length_coded_str(data, pos)

    orig_name, pos = _from_length_coded_str(data, pos)

    pos = pos + 1 -- ignore the filler

    charsetnr, pos = _get_byte2(data, pos)

    length, pos = _get_byte4(data, pos)

    col.type = strbyte(data, pos)

    return col
end

local function _parse_row_data_packet(data, cols, compact)
    local pos = 1
    local ncols = #cols
    local row
    if compact then
        row = new_tab(ncols, 0)
    else
        row = new_tab(0, ncols)
    end
    for i = 1, ncols do
        local value
        value, pos = _from_length_coded_str(data, pos)
        local col = cols[i]
        local typ = col.type
        local name = col.name

        if value ~= null then
            local conv = converters[typ]
            if conv then
                value = conv(value)
            end
        end

        if compact then
            row[i] = value

        else
            row[name] = value
        end
    end

    return row
end

local function _recv_field_packet(self)
    local packet, typ, err = _recv_packet(self)
    if not packet then
        return nil, err
    end

    if typ == RESP_ERR then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    if typ ~= RESP_DATA then
        return nil, "bad field packet type: " .. typ
    end

    -- typ == RESP_DATA

    return _parse_field_packet(packet)
end

-- refer to https://dev.mysql.com/doc/internals/en/connection-phase-packets.html
local function _read_hand_shake_packet(self)
    local packet, typ, err = _recv_packet(self)
    if not packet then
        return nil, nil, err
    end

    if typ == RESP_ERR then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, nil, msg, errno, sqlstate
    end

    local protocol_ver = tonumber(strbyte(packet))
    if not protocol_ver then
        return nil, nil,
            "bad handshake initialization packet: bad protocol version"
    end

    if protocol_ver < MIN_PROTOCOL_VER then
        return nil, nil, "unsupported protocol version " .. protocol_ver
                         .. ", version " .. MIN_PROTOCOL_VER
                         .. " or higher is required"
    end

    self.protocol_ver = protocol_ver

    local server_ver, pos = _from_cstring(packet, 2)
    if not server_ver then
        return nil, nil,
            "bad handshake initialization packet: bad server version"
    end

    self._server_ver = server_ver

    local thread_id, pos = _get_byte4(packet, pos)

    local scramble = sub(packet, pos, pos + 8 - 1)
    if not scramble then
        return nil, nil, "1st part of scramble not found"
    end

    pos = pos + 9 -- skip filler(8 + 1)

    -- two lower bytes
    local capabilities  -- server capabilities
    capabilities, pos = _get_byte2(packet, pos)

    self._server_lang = strbyte(packet, pos)
    pos = pos + 1

    self._server_status, pos = _get_byte2(packet, pos)

    local more_capabilities
    more_capabilities, pos = _get_byte2(packet, pos)

    self.capabilities = bor(capabilities, lshift(more_capabilities, 16))

    pos = pos + 11 -- skip length of auth-plugin-data(1) and reserved(10)

    -- follow official Python library uses the fixed length 12
    -- and the 13th byte is "\0 byte
    local scramble_part2 = sub(packet, pos, pos + 12 - 1)
    if not scramble_part2 then
        return nil, nil, "2nd part of scramble not found"
    end

    pos = pos + 13

    local plugin, _ = _from_cstring(packet, pos)
    if not plugin then
        -- EOF if version (>= 5.5.7 and < 5.5.10) or (>= 5.6.0 and < 5.6.2)
        -- \NUL otherwise
        plugin = sub(packet, pos)
    end

    return scramble .. scramble_part2, plugin
end

local function _append_auth_length(self, data)
    local n = #data

    if n <= 250 then
        data = strchar(n) .. data
        return data, 1 + n
    end

    self.DEFAULT_CLIENT_FLAGS = bor(self.DEFAULT_CLIENT_FLAGS,
                            CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA)

    if n <= 0xffff then
        data = strchar(0xfc, band(n, 0xff), band(rshift(n, 8), 0xff)) .. data
        return data, 3 + n
    end

    if n <= 0xffffff then
        data = strchar(0xfd,
                       band(n, 0xff),
                       band(rshift(n, 8), 0xff),
                       band(rshift(n, 16), 0xff))
               .. data
        return data, 4 + n
    end

    data = strchar(0xfe,
                   band(n, 0xff),
                   band(rshift(n, 8), 0xff),
                   band(rshift(n, 16), 0xff),
                   band(rshift(n, 24), 0xff),
                   band(rshift(n, 32), 0xff),
                   band(rshift(n, 40), 0xff),
                   band(rshift(n, 48), 0xff),
                   band(rshift(n, 56), 0xff))
           .. data
    return data, 9 + n
end

local function _write_hand_shake_response(self, auth_resp, plugin)
    local append_auth, len = _append_auth_length(self, auth_resp)

    local req = _set_byte4(self.DEFAULT_CLIENT_FLAGS)
                .. _set_byte4(self._max_packet_size)
                .. strchar(self.charset)
                .. strrep("\0", 23)
                .. _to_cstring(self.user)
                .. append_auth
                .. _to_cstring(self.database)
                .. _to_cstring(plugin)

    local packet_len = 4 + 4 + 1 + 23 + #self.user + 1
        + len + #self.database + 1 + #plugin + 1

    local bytes, err = _send_packet(self, req, packet_len)
    if not bytes then
        return "failed to send client authentication packet: " .. err
    end

    return nil
end

local function _read_auth_result(self, old_auth_data, plugin)
    local packet, typ, err = _recv_packet(self)
    if not packet then
        return nil, nil, "failed to receive the result packet: " .. err
    end

    if typ == RESP_OK then
        return RESP_OK, ""
    end

    if typ == RESP_AUTHMOREDATA then
        return sub(packet, 2), ""
    end

    if typ == RESP_EOF then
        if #packet == 1 then -- old pre-4.1 authentication protocol
            return nil, "mysql_old_password"
        end

        local pos

        plugin, pos = _from_cstring(packet, 2)
        if not plugin then
            return nil, nil, "malformed packet"
        end

        return sub(packet, pos), plugin
    end

    if typ == RESP_ERR then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return errno, sqlstate, msg
    end

    return nil, nil, "bad packet type: " .. typ
end

local function _read_ok_result(self)
    local packet, typ, err = _recv_packet(self)
    if not packet then
        return "failed to receive the result packet: " .. err
    end

    if typ == RESP_ERR then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return msg, errno, sqlstate
    end

    if typ ~= RESP_OK then
        return "bad packet type: " .. typ
    end
end

local function _auth(self, auth_data, plugin)
    local password = self.password

    if plugin == "mysql_clear_password" then
        return _to_cstring(password)
    end

    if plugin == "mysql_native_password" then
        return _compute_token(password, auth_data)
    end

    return nil, "unknown plugin: " .. plugin
end

local function _handle_auth_result(self, old_auth_data, plugin)
    local auth_data, new_plugin, err = _read_auth_result(self, old_auth_data,
                                                         plugin)

    if err ~= nil then
        local errno, sqlstate = auth_data, new_plugin
        return err, errno, sqlstate
    end

    if auth_data == RESP_OK then
        return
    end

    if new_plugin ~= "" then
        if not auth_data then
            auth_data = old_auth_data
        else
            old_auth_data = auth_data
        end

        plugin = new_plugin

        local auth_resp, err = _auth(self, auth_data, plugin)
        if not auth_resp then
            return err
        end

        local bytes, err = _send_packet(self, auth_resp, #auth_resp)
        if not bytes then
            return "failed to send client authentication packet: " .. err
        end

        auth_data, new_plugin, err = _read_auth_result(self, old_auth_data,
                                                       plugin)

        if err ~= nil then
            local errno, sqlstate = auth_data, new_plugin
            return err, errno, sqlstate
        end

        if auth_data == RESP_OK then
            return
        end

        if new_plugin ~= "" then
            return "malformed packet"
        end
    end

end

local function connect(self, host, port, opts)

    local max_packet_size = opts.max_packet_size
    if not max_packet_size then
        max_packet_size = 1024 * 1024 -- default 1 MB
    end
    self._max_packet_size = max_packet_size

    local fd, err

    self.compact = opts.compact_arrays

    self._proxy = opts.proxy -- whether use proxy mode

    self.database = opts.database or ""
    self.user = opts.user or ""

    self.charset = CHARSET_MAP[opts.charset or "_default"]
    if not self.charset then
        return nil, "charset '" .. opts.charset .. "' is not supported"
    end

    local pool = opts.pool

    self.password = opts.password or ""

    local typ = type(host)
    if typ ~= "string" then
        error("bad argument #1 host: string expected, got " .. typ, 2)
    end

    typ = type(port)
    if typ ~= "number" then
        port = tonumber(port)
        if port == nil then
            error("bad argument #2 port: number expected, got " ..
                    typ, 2)
        end
    end
    
        if not pool then
            pool = self.user .. ":" .. self.database .. ":" .. host .. ":"
                   .. port
        end

        fd, err = socket.connect(host, port, { pool = pool,
                                pool_size = opts.pool_size,
                                backlog = opts.backlog })


    if not fd then
        return nil, 'failed to connect: ' .. err
    end

    self.sock = fd

    if self.state == STATE_CONNECTED then
        return fd
    end

    self.DEFAULT_CLIENT_FLAGS = bor(DEFAULT_CLIENT_FLAGS, CLIENT_PLUGIN_AUTH)

    local auth_data, plugin, err, errno, sqlstate
        = _read_hand_shake_packet(self)

    if err ~= nil then
        return nil, err
    end

    local auth_resp, err = _auth(self, auth_data, plugin)
    if not auth_resp then
        return nil, err
    end

    err = _write_hand_shake_response(self, auth_resp, plugin)
    if err ~= nil then
        return nil, err
    end

    local err, errno, sqlstate = _handle_auth_result(self, auth_data, plugin)
    if err ~= nil then
        return nil, err, errno, sqlstate
    end

    self.state = STATE_CONNECTED

    return fd
end

function _M.new(host, port, opts)
    -- local sock, err = tcp()
    local tab = {}
    
    local sock, err = connect(tab, host, port, opts)
    if not sock then
        return nil, err
    end

    return setmetatable(tab, mt)
end

function _M.set_keepalive(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    if self.state ~= STATE_CONNECTED then
        return nil, "cannot be reused in the current connection state: "
                    .. (self.state or "nil")
    end

    self.state = nil
    return socket.setkeepalive(sock)
end

function _M.close(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    self.state = nil

    local bytes, err = _send_packet(self, strchar(COM_QUIT), 1)
    if not bytes then
        return nil, err
    end

    return socket.close(sock)
end

function _M.server_ver(self)
    return self._server_ver
end

local function send_query(self, query)
    if self.state ~= STATE_CONNECTED then
        return nil, "cannot send query in the current context: "
                    .. (self.state or "nil")
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    self.packet_no = -1

    local cmd_packet = strchar(COM_QUERY) .. query
    local packet_len = 1 + #query

    local bytes, err = _send_packet(self, cmd_packet, packet_len)
    if not bytes then
        return nil, err
    end

    self.state = STATE_COMMAND_SENT

    --print("packet sent ", bytes, " bytes")

    return bytes
end
_M.send_query = send_query

local function read_result(self, est_nrows)
    if not self._proxy and self.state ~= STATE_COMMAND_SENT then
        return nil, "cannot read result in the current context: "
                    .. (self.state or "nil")
    end

    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    local packet, typ, err = _recv_packet(self)
    if not packet then
        return nil, err
    end

    if typ == RESP_ERR then
        self.state = STATE_CONNECTED

        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end

    if typ == RESP_OK then
        local res = _parse_ok_packet(packet)
        if res and band(res.server_status, SERVER_MORE_RESULTS_EXISTS) ~= 0 then
            return res, "again"
        end

        self.state = STATE_CONNECTED
        return res
    end

    if typ == RESP_LOCALINFILE then
        self.state = STATE_CONNECTED

        return nil, "packet type " .. typ .. " not supported"
    end

    -- typ == RESP_DATA or RESP_AUTHMOREDATA(also mean RESP_DATA here)

    local field_count, extra = _parse_result_set_header_packet(packet)

    local cols = new_tab(field_count, 0)
    for i = 1, field_count do
        local col, err, errno, sqlstate = _recv_field_packet(self)
        if not col then
            return nil, err, errno, sqlstate
        end

        cols[i] = col
    end

    local packet, typ, err = _recv_packet(self)
    if not packet then
        return nil, err
    end

    if typ ~= RESP_EOF then
        return nil, "unexpected packet type " .. typ .. " while eof packet is "
            .. "expected"
    end

    -- typ == RESP_EOF

    local compact = self.compact

    local rows = new_tab(est_nrows or 4, 0)
    local i = 0
    while true do

        packet, typ, err = _recv_packet(self)
        if not packet then
            return nil, err
        end

        if typ == RESP_EOF then
            local warning_count, status_flags = _parse_eof_packet(packet)

            if band(status_flags, SERVER_MORE_RESULTS_EXISTS) ~= 0 then
                return rows, "again"
            end

            break
        end

        local row = _parse_row_data_packet(packet, cols, compact)
        i = i + 1
        rows[i] = row
    end

    self.state = STATE_CONNECTED

    return rows
end
_M.read_result = read_result

function _M.query(self, query, est_nrows)
    local bytes, err = send_query(self, query)
    if not bytes then
        return nil, "failed to send query: " .. err
    end

    return read_result(self, est_nrows)
end

function _M.set_compact_arrays(self, value)
    self.compact = value
end

return _M
