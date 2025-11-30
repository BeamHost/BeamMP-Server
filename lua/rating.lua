-- File: lua/rating.lua
-- iRating-inspired global rating system.

local Rating = {}

function Rating.initPlayer(data)
    if not data.rating then data.rating = 1000 end
end

-- lapContext: { isRaceLap, lapTimeMs, position, fieldSize, layoutDifficulty, strengthOfField }
function Rating.updateOnLap(data, ctx)
    Rating.initPlayer(data)
    local base = ctx.isRaceLap and 15 or 5
    local sof = ctx.strengthOfField or 1000
    local expected = sof / math.max(1, data.rating)
    local perf = 1
    if ctx.position and ctx.fieldSize and ctx.position > 0 then
        perf = (ctx.fieldSize - ctx.position + 1) / ctx.fieldSize
    end
    local timeFactor = 1
    if ctx.layoutDifficulty then
        timeFactor = 0.8 + 0.4 * ctx.layoutDifficulty
    end
    local delta = base * timeFactor * (perf - expected * 0.5)
    data.rating = math.max(100, math.floor(data.rating + delta))
    return data.rating
end

return Rating
