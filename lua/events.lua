-- File: lua/events.lua
-- Automatic race/event loop logic.

local json = require("json")
local Tracks

local Events = {
    config = { events = {} },
    currentEvent = nil,
    state = "hotlap",
    lastRaceFinished = 0,
    countdown = nil
}

local function carAllowed(evt, carId)
    if not evt or not evt.allowedCars or #evt.allowedCars == 0 then return true end
    for _, c in ipairs(evt.allowedCars) do
        if c == carId then return true end
    end
    return false
end

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local c = f:read("*a")
    f:close()
    return c
end

function Events.loadConfig()
    local contents = readFile("config/event_loop.json")
    if contents then
        Events.config = json.decode(contents) or { events = {} }
    end
end

function Events.init(tracks)
    Tracks = tracks
    Events.loadConfig()
end

function Events.selectNextEvent()
    if not Events.config.events or #Events.config.events == 0 then return nil end
    local idx = os.time() % #Events.config.events + 1
    Events.currentEvent = Events.config.events[idx]
    if Events.currentEvent then
        Tracks.setCurrentLayout(Events.currentEvent.layoutId)
    end
    return Events.currentEvent
end

function Events.tryStartRace(playerStates)
    local evt = Events.currentEvent or Events.selectNextEvent()
    local now = os.time()
    if not evt or (now - Events.lastRaceFinished) < (evt.raceCooldownSec or 300) then return end
    local ready = {}
    for pid, state in pairs(playerStates) do
        if state.isConnected and (state.currentCar and carAllowed(evt, state.currentCar)) then
            table.insert(ready, { id = pid, rating = (state.userData and state.userData.rating) or 1000 })
        end
    end
    if #ready < (evt.minPlayers or 2) then return end
    table.sort(ready, function(a, b) return a.rating > b.rating end)
    Events.state = "countdown"
    Events.countdown = 15
    Events.grid = ready
    print("[2FastTelemetry] Countdown started for event " .. evt.name)
    return ready
end

function Events.onTick(dt, playerStates)
    if Events.state == "hotlap" then
        Events.tryStartRace(playerStates)
    elseif Events.state == "countdown" then
        Events.countdown = Events.countdown - dt
        if Events.countdown <= 0 then
            Events.state = "race"
            Events.countdown = nil
            Events.spawnOnGrid(playerStates)
            MP.TriggerGlobalEvent("TwoFast:raceStart", Events.currentEvent)
        end
    elseif Events.state == "race" then
        -- race progress managed by timing.lua lap completion
    end
end

function Events.spawnOnGrid(playerStates)
    local layout = Tracks.getCurrentLayout()
    if not layout or not layout.startGrid then return end
    for i, entry in ipairs(Events.grid or {}) do
        local slot = layout.startGrid[i]
        if slot then
            MP.SetPlayerGrid(entry.id, slot.position, slot.rotation or slot.yaw or 0)
            MP.TriggerClientEvent(entry.id, "TwoFast:grid", { index = i, slot = slot })
        end
    end
end

function Events.finishRace()
    Events.lastRaceFinished = os.time()
    Events.state = "hotlap"
    Events.currentEvent = nil
end

function Events.getState()
    return Events.state
end

function Events.getCurrentEvent()
    return Events.currentEvent
end

return Events
