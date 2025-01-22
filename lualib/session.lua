local rbtree = require "gamenet.rbtree"

local function manage_sessions()
    local sessions = rbtree.new()

    local function add_session(session_id, user_data)
        sessions:insert(session_id, user_data)
    end

    local function remove_session(session_id)
        sessions:delete(session_id)
    end

    local function get_session(session_id)
        return sessions:search(session_id)
    end

    local function clear_sessions()
        sessions:destroy()
        sessions = rbtree.new()
    end

    local function get_all_sessions()
        local all_sessions = {}
        for node in sessions:iterator() do
            table.insert(all_sessions, {id = node.key, data = node.value})
        end
        return all_sessions
    end

    local function session_count()
        return sessions:size()
    end

    local function update_session(session_id, new_data)
        local node = sessions:search(session_id)
        if node then
            sessions:delete(session_id)
            sessions:insert(session_id, new_data)
        end
    end

    local function session_exists(session_id)
        return sessions:search(session_id) ~= nil
    end

    local function get_sessions_by_range(start_id, end_id)
        local range_sessions = {}
        for node in sessions:iterator() do
            if node.key >= start_id and node.key <= end_id then
                table.insert(range_sessions, {id = node.key, data = node.value})
            end
        end
        return range_sessions
    end

    return {
        add_session = add_session,
        remove_session = remove_session,
        get_session = get_session,
        clear_sessions = clear_sessions,
        get_all_sessions = get_all_sessions,
        session_count = session_count,
        update_session = update_session,
        session_exists = session_exists,
        get_sessions_by_range = get_sessions_by_range
    }
end

local M = manage_sessions()

return M

-- Usage example: 使用session必须清理，否则会内存泄漏
-- local sessions = require "session"
-- sessions.add_session(1, "User1")
-- sessions.add_session(2, "User2")
-- print(sessions.get_session(1))  -- Output: User1
-- sessions.update_session(1, "UpdatedUser1")
-- print(sessions.get_session(1))  -- Output: UpdatedUser1
-- sessions.remove_session(1)
-- print(sessions.get_session(1))  -- Output: nil
-- print(sessions.get_all_sessions())  -- Output: {{id = 2, data = "User2"}}
-- print(sessions.session_count())  -- Output: 1
-- sessions.clear_sessions()
