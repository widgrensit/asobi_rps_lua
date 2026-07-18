# Best of 3

A four-player Rock-Paper-Scissors royale on [Asobi](https://github.com/widgrensit/asobi).
It's **turn-based**: a round only resolves once everyone has thrown, and the
server holds each throw secretly until the reveal - so no client can peek at the
others or change its pick after the fact. Empty seats fill with bots, so a single
player starts immediately.

Each round you score one point for every opponent your throw beats. Most points
after three rounds wins.

The whole game is the Lua in [`lua/`](lua/):

```
lua/
  config.lua   maps the mode name "bestof3" to match.lua
  match.lua    rounds, hidden throws, server-authoritative scoring
  bots/
    thrower.lua  fills empty seats
```

## Run it locally

Docker only - no account, no keys:

```bash
docker compose up -d
```

Server on `http://localhost:8087` (HTTP API + WebSocket on `/ws`).

## Deploy to Asobi cloud

Unlike the [Live Patch](https://github.com/widgrensit/asobi_livepatch_lua) demo,
this one needs no hot-reload, so it runs fine as a sealed managed game:

```bash
asobi login
asobi use <your-game>
asobi deploy prod lua
```

The browser demo authenticates anonymously via `POST /api/v1/auth/guest`, so
visitors never create an account. That is opt-in via a two-key model: the game
sets `guest_auth = true` in `match.lua` (already set here), and the operator
supplies a strong `ASOBI_GUEST_VERIFIER_PEPPER` (>= 32 bytes). On managed cloud
the pepper is provisioned per environment automatically; self-hosting, you set it
yourself. A short or raw-bytes pepper fails closed, and until both halves are
present the endpoint returns 403 and the samples-page widget shows a self-host
card instead.

## Play it by hand

```bash
curl -sX POST http://localhost:8087/api/v1/auth/register \
  -H 'content-type: application/json' \
  -d '{"username":"p1","password":"secret123"}'
# => {"player_id":"...","access_token":"...","refresh_token":"..."}

npm install -g wscat
wscat -c ws://localhost:8087/ws
> {"type":"session.connect","payload":{"token":"<access_token>"}}
> {"type":"matchmaker.add","payload":{"mode":"bestof3"}}
> {"type":"match.join","payload":{"match_id":"<id>"}}
> {"type":"match.input","payload":{"throw":"rock"}}
```

`match.state` each tick carries the round, the timer, and every player's score;
throws stay hidden until the reveal.
