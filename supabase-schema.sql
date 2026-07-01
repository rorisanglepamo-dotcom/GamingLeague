-- =====================================================================
--  ITSA Gaming League — Supabase Schema
--  Paste this entire file into: Supabase Dashboard → SQL Editor → Run
-- =====================================================================

-- ── Users (mirrors Supabase Auth, stores extra profile data) ──────────
create table if not exists public.users (
    id          uuid primary key references auth.users(id) on delete cascade,
    name        text not null,
    surname     text not null,
    student_no  text not null unique,
    email       text not null unique,
    role        text not null default 'user' check (role in ('user', 'admin')),
    created_at  timestamptz not null default now()
);

-- ── Leagues ───────────────────────────────────────────────────────────
create table if not exists public.leagues (
    id           bigint generated always as identity primary key,
    name         text not null,
    game         text not null,
    status       text not null default 'open' check (status in ('open', 'closed')),
    player_count integer not null default 0,
    created_at   timestamptz not null default now()
);

-- ── Events (upcoming tournaments) ─────────────────────────────────────
create table if not exists public.events (
    id         bigint generated always as identity primary key,
    name       text not null,
    date       date not null,
    game       text not null,
    venue      text not null,
    created_at timestamptz not null default now()
);

-- ── Fixtures ──────────────────────────────────────────────────────────
create table if not exists public.fixtures (
    id         bigint generated always as identity primary key,
    player1_id uuid references public.users(id) on delete set null,
    player2_id uuid references public.users(id) on delete set null,
    league_id  bigint references public.leagues(id) on delete set null,
    date       date not null,
    result     text default 'TBD',
    created_at timestamptz not null default now()
);

-- ── Leaderboard ───────────────────────────────────────────────────────
create table if not exists public.leaderboard (
    id        bigint generated always as identity primary key,
    player_id uuid not null references public.users(id) on delete cascade,
    wins      integer not null default 0,
    losses    integer not null default 0,
    points    integer not null default 0,
    unique (player_id)
);

-- ── League Registrations ──────────────────────────────────────────────
create table if not exists public.league_registrations (
    id         bigint generated always as identity primary key,
    user_id    uuid not null references public.users(id) on delete cascade,
    league_id  bigint not null references public.leagues(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique (user_id, league_id)          -- one registration per user per league
);

-- ── Contact messages ──────────────────────────────────────────────────
create table if not exists public.contact_messages (
    id         bigint generated always as identity primary key,
    name       text not null,
    student_no text not null,
    subject    text not null,
    message    text not null,
    user_id    uuid references public.users(id) on delete set null,
    created_at timestamptz not null default now()
);

-- =====================================================================
--  Row Level Security
-- =====================================================================
alter table public.users             enable row level security;
alter table public.leagues           enable row level security;
alter table public.events            enable row level security;
alter table public.fixtures          enable row level security;
alter table public.leaderboard       enable row level security;
alter table public.contact_messages  enable row level security;
alter table public.league_registrations enable row level security;

-- ── users ─────────────────────────────────────────────────────────────
-- Logged-in users can read all profiles; can only update their own.
create policy "Users can read all profiles"
    on public.users for select
    using (auth.uid() is not null);

create policy "Users can update own profile"
    on public.users for update
    using (auth.uid() = id);

-- Allow insert during sign-up (service role handles this via trigger below)
create policy "Allow own insert"
    on public.users for insert
    with check (auth.uid() = id);

-- ── leagues ───────────────────────────────────────────────────────────
create policy "Authenticated users can read leagues"
    on public.leagues for select
    using (auth.uid() is not null);

create policy "Admins can manage leagues"
    on public.leagues for all
    using (
        exists (select 1 from public.users where id = auth.uid() and role = 'admin')
    );

-- ── events ────────────────────────────────────────────────────────────
create policy "Authenticated users can read events"
    on public.events for select
    using (auth.uid() is not null);

create policy "Admins can manage events"
    on public.events for all
    using (
        exists (select 1 from public.users where id = auth.uid() and role = 'admin')
    );

-- ── fixtures ──────────────────────────────────────────────────────────
create policy "Authenticated users can read fixtures"
    on public.fixtures for select
    using (auth.uid() is not null);

create policy "Admins can manage fixtures"
    on public.fixtures for all
    using (
        exists (select 1 from public.users where id = auth.uid() and role = 'admin')
    );

-- ── leaderboard ───────────────────────────────────────────────────────
create policy "Anyone authenticated can read leaderboard"
    on public.leaderboard for select
    using (auth.uid() is not null);

create policy "Admins can manage leaderboard"
    on public.leaderboard for all
    using (
        exists (select 1 from public.users where id = auth.uid() and role = 'admin')
    );

-- ── league_registrations ──────────────────────────────────────────────
create policy "Users can read own registrations"
    on public.league_registrations for select
    using (auth.uid() = user_id);

create policy "Users can register themselves"
    on public.league_registrations for insert
    with check (auth.uid() = user_id);

create policy "Users can unregister themselves"
    on public.league_registrations for delete
    using (auth.uid() = user_id);

create policy "Admins can read all registrations"
    on public.league_registrations for select
    using (
        exists (select 1 from public.users where id = auth.uid() and role = 'admin')
    );

-- ── contact_messages ──────────────────────────────────────────────────
create policy "Users can insert messages"
    on public.contact_messages for insert
    with check (auth.uid() is not null);

create policy "Admins can read all messages"
    on public.contact_messages for select
    using (
        exists (select 1 from public.users where id = auth.uid() and role = 'admin')
    );

create policy "Admins can delete messages"
    on public.contact_messages for delete
    using (
        exists (select 1 from public.users where id = auth.uid() and role = 'admin')
    );

-- =====================================================================
--  Auto-insert into public.users when a new Auth user signs up
--  (the app also does this client-side; this trigger is a safety net)
-- =====================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
    insert into public.users (id, name, surname, student_no, email, role)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'name', ''),
        coalesce(new.raw_user_meta_data->>'surname', ''),
        coalesce(new.raw_user_meta_data->>'student_no', ''),
        new.email,
        'user'
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

-- =====================================================================
--  Auto-update leagues.player_count on registration changes
-- =====================================================================
create or replace function public.update_league_player_count()
returns trigger language plpgsql security definer as $$
begin
    if TG_OP = 'INSERT' then
        update public.leagues set player_count = player_count + 1 where id = NEW.league_id;
    elsif TG_OP = 'DELETE' then
        update public.leagues set player_count = greatest(player_count - 1, 0) where id = OLD.league_id;
    end if;
    return null;
end;
$$;

drop trigger if exists on_league_registration on public.league_registrations;
create trigger on_league_registration
    after insert or delete on public.league_registrations
    for each row execute procedure public.update_league_player_count();

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();
