# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Palmyst** is a palm-reading and self-discovery mobile app. Users upload palm photos that are analysed by AI to generate insights across life categories (Relationship, Finance, Career, Health, Growth, Personal Life).

- **Frontend:** FlutterFlow (no app source code in this repo)
- **Backend:** Supabase (PostgreSQL 17) — this repo manages the DB schema and migrations
- **Design:** Figma mockups exported to `doc/` as images

## Supabase CLI Commands

```bash
# Start local Supabase stack (Docker required)
npx supabase start

# Stop local stack
npx supabase stop

# Apply migrations to local DB
npx supabase db reset

# Push migrations to remote/production
npx supabase db push

# Generate a new migration from local schema diff
npx supabase db diff -f <migration_name>

# Pull remote schema into a new migration
npx supabase db pull
```

Local services after `supabase start`:
- API: `http://127.0.0.1:54321`
- Studio: `http://127.0.0.1:54323`
- DB: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`

## Repository Structure

```
supabase/
  config.toml          # Local Supabase project config (project_id = "palmyst")
  migrations/          # SQL migration files (apply in order)
doc/
  db-schema.md         # Full schema documentation with ER diagram
  palmyst_app_figma_image_page-*.jpg  # Figma UI screenshots
```

## Database Architecture

Full schema reference: [`doc/db-schema.md`](doc/db-schema.md)

### Core Entity Hierarchy

```
auth.users (Supabase managed)
  └── profiles              1:1 extension; holds credit_balance, preferred_language_id, referred_by
        ├── palms            N palm profiles per user (constraint: one is_self=true per owner)
        ├── credit_transactions
        ├── user_purchases
        ├── tool_sessions    AI analysis runs
        │     ├── tool_session_metrics   percentage scores per category
        │     ├── session_solutions      traditional / science_backed advice
        │     ├── user_action_progress   sequential action plan steps
        │     └── tool_reviews
        ├── chat_sessions
        │     └── chat_messages
        └── notifications

categories → tools → tool_features
subscription_plans → user_purchases ← promo_codes
languages   (lookup)
banners     (CMS promotional content)
```

### Key Design Decisions

- All tables use `uuid` PKs with `gen_random_uuid()`.
- `set_updated_at()` trigger maintains `updated_at` on all mutable tables.
- `handle_new_user()` trigger fires on `auth.users` INSERT to create a `profiles` row with a 5-credit welcome bonus.
- Row Level Security (RLS) is enabled on all tables; users can only read/write their own rows.
- `palms.is_self` is enforced unique per owner via a partial index.
- Credits flow: earn on signup/review/share/referral; spend on tool usage and solution unlocks; purchase via in-app purchase (`user_purchases`).
- `tool_sessions.status` follows: `pending` → `processing` → `completed` / `failed`.
- `session_solutions.type`: `traditional` | `science_backed`.

### ENUM Types

| Type | Values |
|---|---|
| `gender_enum` | `male`, `female`, `other`, `prefer_not_to_say` |
| `session_status` | `pending`, `processing`, `completed`, `failed` |
| `solution_type` | `traditional`, `science_backed` |
| `action_status` | `locked`, `available`, `completed` |
| `reflection_feeling` | `felt_good`, `was_uncomfortable`, `not_sure_yet` |
| `message_role` | `user`, `assistant` |
| `credit_type` | `signup_bonus`, `tool_usage`, `solution_unlock`, `purchase`, `referral_bonus`, `review_reward`, `share_reward`, `admin_grant`, `promo_bonus` |
| `discount_type` | `percentage`, `fixed` |
| `payment_status` | `pending`, `completed`, `failed`, `refunded` |


## Development rules
- NO COMMENTS except for genuinely complex logic
- Self-documenting code with clear names
- Concise responses; minimize explanations
- Small, PR-ready changes with tests
- Use Early Return code pattern
- Config npm package is configured for this project use that for ENV reading and ENV management
- When working with Supabase db make sure to add relevant Row level security (RLS) for tables if not there
- When running supabase command it must use `npx` as supabase cli is installed only on project level
- When running supabase command it should run on the local setup and not on claude. Use --local flag when possible, example `npx supabase db reset --local`
- No default Values for ENVs in code. If we need default it should come from config `default.json`
- No Long name if not required
- Do not edit supabase migration which already commit to git commit.
- Any non git commit changes to supabase migration can be edited and should only create migration when old migration is pushed to server / remote
