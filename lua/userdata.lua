-- File: lua/userdata.lua
-- Helper for loading/saving player JSON data.

local json = require("json")
local UserData = {}

local dataDir = "userData"

local function ensureDir()
    os.execute("mkdir -p " .. dataDir)
end

local function isGuestName(name)
    if not name then return true end
    if name:match("^%d+$") then return true end
    if name:lower():match("^guest") then return true end
    return false
end

local function filePath(name)
    return string.format("%s/%s.json", dataDir, name)
end

function UserData.load(name)
    if isGuestName(name) then return { name = name or "guest" } end
    ensureDir()
    local path = filePath(name)
    local f = io.open(path, "r")
    if not f then
        local fresh = { name = name, rating = 1000, carsDriven = {}, tracksDriven = {}, totalLapsCompleted = 0, totalRaceTimeMs = 0, raceWins = 0, raceLossesOrStarts = 0, autoEventsParticipated = 0 }
        return fresh
    end
    local content = f:read("*a")
    f:close()
    local data = json.decode(content) or {}
    data.name = name
    return data
end

function UserData.save(name, data)
    if isGuestName(name) then return end
    ensureDir()
    local path = filePath(name)
    local f = io.open(path, "w+")
    if not f then return end
    f:write(json.encode(data))
    f:close()
end

function UserData.updateOnLap(playerName, layoutId, carId, lapTime, sectors, isRaceLap, position, fieldSize)
    local data = UserData.load(playerName)
    data.totalLapsCompleted = (data.totalLapsCompleted or 0) + 1
    data.totalRaceTimeMs = (data.totalRaceTimeMs or 0) + (lapTime or 0)
    data.carsDriven[carId] = data.carsDriven[carId] or { laps = 0, bestLapMs = nil }
    local carInfo = data.carsDriven[carId]
    carInfo.laps = carInfo.laps + 1
    if not carInfo.bestLapMs or lapTime < carInfo.bestLapMs then
        carInfo.bestLapMs = lapTime
    end
    data.tracksDriven[layoutId] = data.tracksDriven[layoutId] or { laps = 0, bestLapMs = nil }
    local layoutInfo = data.tracksDriven[layoutId]
    layoutInfo.laps = layoutInfo.laps + 1
    if not layoutInfo.bestLapMs or lapTime < layoutInfo.bestLapMs then
        layoutInfo.bestLapMs = lapTime
    end
    if isRaceLap then
        data.raceLossesOrStarts = (data.raceLossesOrStarts or 0) + 1
        if position and position == 1 then
            data.raceWins = (data.raceWins or 0) + 1
        end
    end
    if sectors then
        data.splitHistory = data.splitHistory or {}
        table.insert(data.splitHistory, { layoutId = layoutId, lapTimeMs = lapTime, sectors = sectors, isRaceLap = isRaceLap })
        if #data.splitHistory > 10 then table.remove(data.splitHistory, 1) end
    end
    UserData.save(playerName, data)
    return data
end

return UserData
