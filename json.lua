-- File: json.lua
-- Simple JSON encode/decode helper with a tiny fallback parser for BeamMP Lua.
-- Tries to use dkjson or cjson when available, otherwise falls back to a
-- minimal pure-Lua implementation good enough for configuration and userdata.

local json = {}

local function escape_str(s)
    local replacements = {['\\'] = '\\\\', ['"'] = '\\"', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'}
    return s:gsub('[\\\"\b\f\n\r\t]', replacements)
end

local function is_array(tbl)
    local i = 0
    for _ in pairs(tbl) do
        i = i + 1
        if tbl[i] == nil then return false end
    end
    return true
end

local function encode_value(v)
    local t = type(v)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "number" then
        return tostring(v)
    elseif t == "string" then
        return '"' .. escape_str(v) .. '"'
    elseif t == "table" then
        local parts = {}
        if is_array(v) then
            for i = 1, #v do
                table.insert(parts, encode_value(v[i]))
            end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            for k, val in pairs(v) do
                table.insert(parts, '"' .. escape_str(tostring(k)) .. '"' .. ':' .. encode_value(val))
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    else
        return '"<unsupported>"'
    end
end

local function fallback_decode(str)
    -- Very small JSON decoder that supports numbers, booleans, null, strings,
    -- arrays and objects. Not streaming optimized, but good enough for config.
    local pos = 1
    local function skip_ws()
        local _, e = str:find("^[\n\r\t ]*", pos)
        pos = (e or pos - 1) + 1
    end
    local function decode_value()
        skip_ws()
        local ch = str:sub(pos, pos)
        if ch == '"' then
            local start = pos + 1
            local i = start
            local res = {}
            while i <= #str do
                local c = str:sub(i, i)
                if c == '"' then
                    pos = i + 1
                    return table.concat(res)
                elseif c == '\\' then
                    local nxt = str:sub(i + 1, i + 1)
                    local map = {['\\'] = '\\', ['"'] = '"', ['b'] = '\b', ['f'] = '\f', ['n'] = '\n', ['r'] = '\r', ['t'] = '\t'}
                    table.insert(res, map[nxt] or nxt)
                    i = i + 2
                else
                    table.insert(res, c)
                    i = i + 1
                end
            end
        elseif ch == '{' then
            pos = pos + 1
            local obj = {}
            skip_ws()
            if str:sub(pos, pos) == '}' then
                pos = pos + 1
                return obj
            end
            while true do
                local key = decode_value()
                skip_ws()
                pos = pos + 1 -- skip :
                local val = decode_value()
                obj[key] = val
                skip_ws()
                local delim = str:sub(pos, pos)
                if delim == '}' then
                    pos = pos + 1
                    break
                end
                pos = pos + 1 -- skip ,
            end
            return obj
        elseif ch == '[' then
            pos = pos + 1
            local arr = {}
            skip_ws()
            if str:sub(pos, pos) == ']' then
                pos = pos + 1
                return arr
            end
            while true do
                table.insert(arr, decode_value())
                skip_ws()
                local delim = str:sub(pos, pos)
                if delim == ']' then
                    pos = pos + 1
                    break
                end
                pos = pos + 1 -- skip ,
            end
            return arr
        else
            local literals = {['true'] = true, ['false'] = false, ['null'] = nil}
            for lit, val in pairs(literals) do
                if str:sub(pos, pos + #lit - 1) == lit then
                    pos = pos + #lit
                    return val
                end
            end
            local num = str:match('^-?%d+%.?%d*[eE]?%-?%d*', pos)
            if num then
                pos = pos + #num
                return tonumber(num)
            end
        end
        return nil
    end
    local ok, res = pcall(decode_value)
    if ok then return res end
    return nil, res
end

function json.encode(tbl)
    local ok, lib = pcall(require, "dkjson")
    if ok and lib then return lib.encode(tbl) end
    local ok2, lib2 = pcall(require, "cjson")
    if ok2 and lib2 then return lib2.encode(tbl) end
    return encode_value(tbl)
end

function json.decode(str)
    -- strip leading comment lines that start with // or # to allow annotated files
    str = str:gsub("^%s*(//.-\n)+", "")
             :gsub("^%s*(#.-\n)+", "")
    local ok, lib = pcall(require, "dkjson")
    if ok and lib then return lib.decode(str) end
    local ok2, lib2 = pcall(require, "cjson")
    if ok2 and lib2 then return lib2.decode(str) end
    return fallback_decode(str)
end

return json
