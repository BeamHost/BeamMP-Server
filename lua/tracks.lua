-- File: lua/tracks.lua
-- Track and layout management.

local json = require("json")
local Tracks = {
    layouts = {},
    currentLayoutId = nil
}

local trackDir = "tracks"

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

function Tracks.loadAllTracks()
    Tracks.layouts = {}
    for file in io.popen('ls -1 ' .. trackDir .. '/*.json'):lines() do
        local contents = readFile(file)
        if contents then
            local layout, err = json.decode(contents)
            if layout and layout.layoutId then
                Tracks.layouts[layout.layoutId] = layout
            else
                print("[2FastTelemetry] Failed to decode track layout from " .. file .. (err or ""))
            end
        end
    end
    print("[2FastTelemetry] Loaded layouts: " .. tostring(#Tracks.getAllLayoutIds()))
end

function Tracks.getAllLayoutIds()
    local ids = {}
    for id, _ in pairs(Tracks.layouts) do
        table.insert(ids, id)
    end
    table.sort(ids)
    return ids
end

function Tracks.getLayoutById(layoutId)
    return Tracks.layouts[layoutId]
end

function Tracks.setCurrentLayout(layoutId)
    if Tracks.layouts[layoutId] then
        Tracks.currentLayoutId = layoutId
        print("[2FastTelemetry] Current layout set to " .. layoutId)
        return true
    end
    return false
end

function Tracks.getCurrentLayout()
    if not Tracks.currentLayoutId then
        local ids = Tracks.getAllLayoutIds()
        Tracks.currentLayoutId = ids[1]
    end
    return Tracks.layouts[Tracks.currentLayoutId]
end

return Tracks
