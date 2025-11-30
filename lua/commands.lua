-- File: lua/commands.lua
-- Chat command definitions.

local Commands = {}
local Tracks, Timing, RatingMod

local function reply(playerId, msg)
    MP.SendChatMessage(playerId, "[2Fast] " .. msg)
end

function Commands.init(tracks, timing, rating)
    Tracks = tracks
    Timing = timing
    RatingMod = rating
    MP.RegisterChatCommand("2fast", Commands.help)
    MP.RegisterChatCommand("telemetry", Commands.help)
    MP.RegisterChatCommand("rating", Commands.rating)
    MP.RegisterChatCommand("laps", Commands.laps)
    MP.RegisterChatCommand("event", Commands.event)
end

function Commands.help(playerId)
    reply(playerId, "2FastTelemetry: /rating /laps /event")
end

function Commands.rating(playerId)
    local state = Timing.getPlayerState(playerId)
    if state and state.userData then
        reply(playerId, string.format("Rating: %d", state.userData.rating or 1000))
    else
        reply(playerId, "No rating data yet. Drive a lap!")
    end
end

function Commands.laps(playerId)
    local layout = Tracks.getCurrentLayout()
    local state = Timing.getPlayerState(playerId)
    if not state or not layout then
        reply(playerId, "No lap data yet.")
        return
    end
    local car = state.currentCar or "unknown"
    local info = state.userData and state.userData.carsDriven and state.userData.carsDriven[car]
    local best = info and info.bestLapMs or state.bestLapTime
    reply(playerId, string.format("Layout %s | Car %s | Best %.3fs | Laps %d", layout.layoutName, car, (best or 0)/1000, state.completedLaps or 0))
end

function Commands.event(playerId)
    local evt = Timing.getCurrentEvent and Timing.getCurrentEvent()
    if evt then
        reply(playerId, string.format("Current event: %s (%d laps)", evt.name, evt.laps or 0))
    else
        reply(playerId, "No scheduled event. Hotlap mode active.")
    end
end

return Commands
