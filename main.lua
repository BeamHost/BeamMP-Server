-- File: main.lua
-- 2FastTelemetry entry point for BeamMP 3.x

package.path = package.path .. ';./?.lua;./lua/?.lua'

local json = require("json")
local Tracks = require("lua/tracks")
local Timing = require("lua/timing")
local Commands = require("lua/commands")
local Events = require("lua/events")
local UserData = require("lua/userdata")
local Rating = require("lua/rating")

local tickInterval = 0.05

local function init()
    print("[2FastTelemetry] Initializing...")
    Tracks.loadAllTracks()
    Events.init(Tracks)
    Timing.init(Tracks, Events)
    Commands.init(Tracks, Timing, Rating)
    print("[2FastTelemetry] Initialization complete")
end

-- BeamMP hooks
MP.RegisterEvent("onPlayerJoining", function(pid)
    local name = MP.GetPlayerName(pid)
    Timing.onPlayerLoaded(pid, name)
    MP.TriggerClientEvent(pid, "TwoFast:boot", { message = "Welcome to 2FastTelemetry" })
end)

MP.RegisterEvent("onPlayerDropped", function(pid)
    Timing.onPlayerLeave(pid)
end)

MP.RegisterEvent("onVehicleSpawn", function(pid, vehId)
    local carId = MP.GetPlayerVehicleMPCarName(pid, vehId)
    Timing.onVehicleChange(pid, carId)
end)

MP.RegisterEvent("onVehicleReset", function(pid)
    Timing.onVehicleReset(pid)
end)

MP.RegisterEvent("onPlayerTeleport", function(pid)
    Timing.onTeleport(pid)
end)

MP.RegisterEvent("onPlayerCheckpoint", function(pid, checkpoint)
    Timing.onCheckpoint(pid, checkpoint)
end)

MP.RegisterEvent("onChatMessage", function(pid, name, message)
    return MP.ProcessChatCommand(pid, message)
end)

MP.RegisterEvent("onTick", function(dt)
    Timing.onTick(dt)
    Events.onTick(dt, Timing.players)
end)

init()
