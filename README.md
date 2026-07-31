# One Night Werewolf

A backend-driven One Night Ultimate Werewolf app for 3–8 players. The home
screen supports local pass-and-play as well as persisted create/join room
lobbies. FastAPI owns the rules and stores every room, action, vote, and result
in Supabase; each client only renders server responses and submits player
intent.

- `backend/` — FastAPI game API and Supabase persistence
- `one_night_werewolf_phone_app/` — Flutter phone app
- `one_night_werewolf_wechat/` — native WeChat Mini Program

See each client directory's README for local setup and deployment notes.
