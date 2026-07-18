-- match.lua - "Best of 3": a four-player Rock-Paper-Scissors royale on Asobi.
-- Turn-based, not real-time: a round only resolves once everyone has thrown, and
-- the server holds each throw secretly until the reveal. Empty seats fill with
-- bots so a visitor plays immediately. Each round you score one point per
-- opponent your throw beats; most points after three rounds wins. Deploys to
-- managed Asobi cloud as an ordinary game (no hot-reload needed).

match_size = 4
max_players = 4
strategy = "fill"
bots = { script = "bots/thrower.lua" }

local ROUNDS = 3
local CHOOSE_TICKS = 100
local REVEAL_TICKS = 30
local FINAL_TICKS = 50

local BEATS = { rock = "scissors", paper = "rock", scissors = "paper" }

local function all_thrown(state)
    for _, p in pairs(state.players) do
        if not p.throw then
            return false
        end
    end
    return true
end

local function display_name(id)
    if string.sub(id, 1, 4) == "bot_" then
        return string.sub(id, 5)
    end
    return "you"
end

local function resolve(state)
    for id, p in pairs(state.players) do
        local s = 0
        for oid, o in pairs(state.players) do
            if oid ~= id and p.throw and BEATS[p.throw] == o.throw then
                s = s + 1
            end
        end
        p.round_score = s
        p.total = p.total + s
    end
    state.phase = "reveal"
    state.timer = REVEAL_TICKS
    game.broadcast("reveal", { round = state.round })
end

function init(config)
    return { players = {}, round = 1, phase = "choosing", timer = CHOOSE_TICKS }
end

function join(player_id, state)
    state.players[player_id] = { throw = nil, total = 0, round_score = 0 }
    return state
end

function leave(player_id, state)
    state.players[player_id] = nil
    return state
end

function handle_input(player_id, input, state)
    if state.phase ~= "choosing" then
        return state
    end
    local p = state.players[player_id]
    if not p or p.throw or not input then
        return state
    end
    local t = input.throw
    if t ~= "rock" and t ~= "paper" and t ~= "scissors" then
        return state
    end
    p.throw = t
    if all_thrown(state) then
        resolve(state)
    end
    return state
end

local function next_round(state)
    state.round = state.round + 1
    state.phase = "choosing"
    state.timer = CHOOSE_TICKS
    for _, p in pairs(state.players) do
        p.throw = nil
        p.round_score = 0
    end
end

local function new_match(state)
    state.round = 1
    state.phase = "choosing"
    state.timer = CHOOSE_TICKS
    for _, p in pairs(state.players) do
        p.throw = nil
        p.total = 0
        p.round_score = 0
    end
    game.broadcast("newmatch", {})
end

function tick(state)
    state.timer = state.timer - 1
    if state.timer > 0 then
        return state
    end

    if state.phase == "choosing" then
        resolve(state)
    elseif state.phase == "reveal" then
        if state.round >= ROUNDS then
            state.phase = "final"
            state.timer = FINAL_TICKS
            game.broadcast("final", {})
        else
            next_round(state)
        end
    elseif state.phase == "final" then
        new_match(state)
    end
    return state
end

function get_state(player_id, state)
    local reveal = state.phase == "reveal" or state.phase == "final"
    local players = {}
    local leader, best = nil, -1
    for id, p in pairs(state.players) do
        if p.total > best then
            leader, best = id, p.total
        end
        local entry = {
            name = display_name(id),
            total = p.total,
            locked = p.throw ~= nil,
            is_you = id == player_id
        }
        if reveal then
            entry.throw = p.throw
            entry.round_score = p.round_score
        end
        players[#players + 1] = entry
    end
    return {
        phase = state.phase,
        round = state.round,
        rounds = ROUNDS,
        secs_left = math.max(0, math.ceil(state.timer / 10)),
        winner = (state.phase == "final") and display_name(leader) or nil,
        players = players
    }
end
