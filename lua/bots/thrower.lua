-- thrower.lua - a bot for Best of 3. Each tick, if a round is open and it hasn't
-- thrown yet, it throws at random. It only ever reads its own slot from state.
names = {"Rocky", "Scizz", "Paperboy", "Dux", "Gambit"}

local THROWS = { "rock", "paper", "scissors" }

function think(bot_id, state)
    if state.phase ~= "choosing" then
        return {}
    end
    local me = state.players and state.players[bot_id]
    if not me or me.throw then
        return {}
    end
    return { throw = THROWS[math.random(3)] }
end
