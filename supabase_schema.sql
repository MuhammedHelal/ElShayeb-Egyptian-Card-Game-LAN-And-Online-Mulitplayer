-- 1. Create the table (if it doesn't exist)
create table if not exists public.rooms (
  id uuid not null default gen_random_uuid (),
  room_code text not null,
  host_id uuid not null, -- Changed to UUID to match auth.uid()
  game_state jsonb not null,
  status text not null default 'waiting'::text,
  created_at timestamp with time zone not null default now(),
  constraint rooms_pkey primary key (id),
  constraint rooms_room_code_key unique (room_code)
);

-- 2. Enable Realtime
alter publication supabase_realtime add table public.rooms;

-- 3. Enable Row Level Security (RLS)
-- This locks down the table so policies determine access
alter table public.rooms enable row level security;

-- 4. Policies

-- Policy: READ Access
-- Allow anyone authenticated (including anonymous users) to view rooms
-- This is required so players can join and spectate.
create policy "Allow read access for all users"
on public.rooms
for select
to authenticated
using (true);

-- Policy: INSERT Access
-- Allow authenticated users to create a room.
-- We enforce that they cannot impersonate others by checking host_id = auth.uid()
create policy "Allow insert for self"
on public.rooms
for insert
to authenticated
with check (auth.uid() = host_id);

-- Policy: UPDATE Access
-- CRITICAL: Only the Host (owner) can update the room state.
-- This prevents other players from overwriting the game state.
create policy "Allow update for host only"
on public.rooms
for update
to authenticated
using (auth.uid() = host_id)
with check (auth.uid() = host_id);

-- Policy: DELETE Access
-- Only the host can delete their room.
create policy "Allow delete for host only"
on public.rooms
for delete
to authenticated
using (auth.uid() = host_id);
