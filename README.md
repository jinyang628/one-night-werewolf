# One Night Werewolf

A backend-driven One Night Ultimate Werewolf app for 3–8 players. The home
screen supports local pass-and-play as well as persisted create/join room
lobbies. FastAPI owns the rules and stores every room, action, vote, and result
in Supabase; Flutter only renders server responses and submits player intent.
