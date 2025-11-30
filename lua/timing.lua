-- File: lua/timing.lua
-- Lap timing and split logic.

local json = require("json")
local UserData = require("lua/userdata")
local Rating = require("lua/rating")
local Tracks
local Events

local Timing = {
    players = {},
    tickAccumulator = 0,
    tickInterval = 0.05
}

local function nowMs()
    return math.floor(os.clock() * 1000)
end

local function newPlayerState(pid, name)
    local data = UserData.load(name)
    Rating.initPlayer(data)
    return {
        id = pid,
        name = name,
        userData = data,
        currentLapStart = nil,
        currentSectorIndex = 1,
        currentLayoutId = nil,
        currentCar = nil,
        bestLapTime = nil,
        bestSplits = {},
        deltaToPB = 0,
        completedLaps = 0,
        isConnected = true,
        isLapInvalid = false,
        raceLap = false
    }
end

local function sendUI(pid, payload)
    MP.TriggerClientEvent(pid, "TwoFast:update", payload)
end

function Timing.init(tracks, events)
    Tracks = tracks
    Events = events
end

function Timing.onPlayerLoaded(pid, name)
    Timing.players[pid] = newPlayerState(pid, name)
end

function Timing.onPlayerLeave(pid)
    Timing.players[pid] = nil
end

function Timing.onVehicleChange(pid, carId)
    local p = Timing.players[pid]
    if p then p.currentCar = carId end
end

function Timing.invalidateLap(pid, reason)
    local p = Timing.players[pid]
    if not p then return end
    p.isLapInvalid = true
    sendUI(pid, { message = "Lap invalidated: " .. (reason or "unknown") })
end

function Timing.onVehicleReset(pid)
    Timing.invalidateLap(pid, "vehicle reset")
end

function Timing.onTeleport(pid)
    Timing.invalidateLap(pid, "teleport")
end

function Timing.onCheckpoint(pid, checkpoint)
    handleCheckpoint(pid, checkpoint)
end

local function handleCheckpoint(pid, checkpoint)
    local p = Timing.players[pid]
    if not p then return end
    if p.isLapInvalid then return end
    if checkpoint.sectorIndex and checkpoint.sectorIndex > p.currentSectorIndex then
        local elapsed = nowMs() - (p.currentLapStart or nowMs())
        p.currentSectorIndex = checkpoint.sectorIndex
        sendUI(pid, { sector = checkpoint.sectorIndex, splitMs = elapsed })
    end
    if checkpoint.id == 1 and p.currentSectorIndex > 1 then
        -- Crossed start/finish
        local lapTime = nowMs() - (p.currentLapStart or nowMs())
        Timing.finishLap(pid, lapTime)
    end
end

function Timing.finishLap(pid, lapTime)
    local p = Timing.players[pid]
    if not p then return end
    if p.isLapInvalid then
        sendUI(pid, { lapInvalid = true })
        p.currentLapStart = nowMs()
        p.currentSectorIndex = 1
        p.isLapInvalid = false
        return
    end
    p.completedLaps = (p.completedLaps or 0) + 1
    if not p.bestLapTime or lapTime < p.bestLapTime then
        p.bestLapTime = lapTime
    end
    local layout = Tracks.getCurrentLayout()
    local car = p.currentCar or "unknown"
    local sectors = { currentSector = p.currentSectorIndex }
    p.userData = UserData.updateOnLap(p.name, layout.layoutId, car, lapTime, sectors, Events.getState() == "race", p.position, p.fieldSize)
    Rating.updateOnLap(p.userData, { isRaceLap = Events.getState() == "race", lapTimeMs = lapTime, position = p.position, fieldSize = p.fieldSize, layoutDifficulty = #layout.checkpoints / 20 })
    UserData.save(p.name, p.userData)
    sendUI(pid, { lapComplete = lapTime, bestLap = p.bestLapTime, laps = p.completedLaps })
    p.currentLapStart = nowMs()
    p.currentSectorIndex = 1
    p.isLapInvalid = false
end

local function updatePlayer(pid, dt)
    local p = Timing.players[pid]
    if not p then return end
    local layout = Tracks.getCurrentLayout()
    if not layout then return end
    p.currentLayoutId = layout.layoutId
    -- placeholder for vehicle data retrieval; BeamMP API should provide position
    -- Here we only tick timer and send UI updates
    if not p.currentLapStart then p.currentLapStart = nowMs() end
    local elapsed = nowMs() - p.currentLapStart
    sendUI(pid, { lapTime = elapsed, bestLap = p.bestLapTime, delta = p.deltaToPB, layout = layout.layoutName, sector = p.currentSectorIndex })
end

function Timing.onTick(dt)
    Timing.tickAccumulator = Timing.tickAccumulator + dt
    if Timing.tickAccumulator < Timing.tickInterval then return end
    local steps = math.floor(Timing.tickAccumulator / Timing.tickInterval)
    Timing.tickAccumulator = Timing.tickAccumulator - steps * Timing.tickInterval
    for _ = 1, steps do
        for pid, _ in pairs(Timing.players) do
            updatePlayer(pid, Timing.tickInterval)
        end
    end
end

function Timing.getPlayerState(pid)
    return Timing.players[pid]
end

function Timing.getCurrentEvent()
    if Events then return Events.getCurrentEvent() end
end

return Timing
