# El-Shayeb authoritative online server

Cloudflare Worker and SQLite-backed Durable Object for hostless online play.

## Commands

```bash
npm install
npm run typecheck
npm test
npm run dev
npm run deploy
```

Copy `.dev.vars.example` to `.dev.vars` for local development. Never commit
`.dev.vars`. For Cloudflare, store `SUPABASE_PUBLISHABLE_KEY` with
`npx wrangler secret put SUPABASE_PUBLISHABLE_KEY`.

The deployed development URL is:

`https://elshayeb-online.elshayeb.workers.dev`

The server owns the 49-card deck, private hands, turns, legal draw target, pair
removal, finish positions, round scores, disconnect progression, and reconnect
state. Clients submit only authenticated intents with an
`expectedStateVersion`; stale or illegal actions are rejected.

Supported room commands are `create_room`, `join_room`, `resume_room`,
`leave_room`, `start_game`, `draw_card`, `shuffle_hand`, and
`start_new_round`. Each `room_snapshot` contains the receiving player's hand
and only public card counts for every opponent.
