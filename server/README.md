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

The current milestone supports authenticated lobby rooms only. Card gameplay
remains disabled until the authoritative rules and private player views are
implemented and tested.
