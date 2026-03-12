# Palmyst — Project Core Documentation

> Version: 1.1.0 | Backend: Supabase (PostgreSQL 17) | AI: Anthropic Claude | Frontend: FlutterFlow

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [System Architecture](#2-system-architecture)
3. [Technology Stack](#3-technology-stack)
4. [Project Structure](#4-project-structure)
5. [Database Design](#5-database-design)
6. [Backend Logic](#6-backend-logic)
7. [Authentication & Security](#7-authentication--security)
8. [External Integrations](#8-external-integrations)
9. [Environment Configuration](#9-environment-configuration)
10. [Development Workflow](#10-development-workflow)
11. [Deployment Architecture](#11-deployment-architecture)
12. [Key Concepts & Business Logic](#12-key-concepts--business-logic)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Project Overview

**Palmyst** is a palm-reading and self-discovery mobile application. Users upload photos of their palms, which are analysed by AI to generate personalised insights across six life categories: **Relationship, Finance, Career, Health, Growth, and Personal Life**.

### Key Goals

- Provide a seamless palm-reading experience powered by AI vision analysis
- Gate premium AI tools behind a credit system to monetise the product
- Support a full in-app purchase flow (Stripe and RevenueCat) to sell credit bundles
- Enable a conversational AI assistant that is aware of a user's reading results
- Encourage engagement through referrals, reviews, shares, and sequential action plans

### Feature Summary

| Feature | Description |
|---|---|
| Authentication | Email/password, Google OAuth, Facebook OAuth |
| Palm Management | Upload and manage multiple palm profiles (self + others) |
| AI Analysis | Credit-gated palm readings across 6 life categories |
| Solutions | Traditional and science-backed advice, unlockable with credits |
| Action Plans | Sequential action steps linked to each analysis session |
| Chat | Conversational AI assistant, context-aware of palm reading results |
| Credits | Earn on signup, reviews, shares, referrals; spend on tools and unlocks |
| Subscriptions | One-time plans granting credit bundles |
| Promo Codes | Discount codes applied at checkout |
| Notifications | In-app notification feed for session status, purchases, referrals |
| Banners | CMS-managed promotional content with time-window controls |

---

## 2. System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FlutterFlow App                          │
│                  (Mobile Frontend — iOS / Android)              │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTPS
               ┌────────────────▼────────────────┐
               │         Supabase Platform        │
               │                                  │
               │  ┌──────────┐  ┌──────────────┐  │
               │  │  Auth    │  │  PostgREST   │  │
               │  │ (JWT)    │  │  (REST API)  │  │
               │  └──────────┘  └──────────────┘  │
               │                                  │
               │  ┌──────────────────────────────┐ │
               │  │      Edge Functions (Deno 2)  │ │
               │  │  analyze-palm │ chat │ pay   │ │
               │  └──────────────────────────────┘ │
               │                                  │
               │  ┌──────────┐  ┌──────────────┐  │
               │  │ Storage  │  │ PostgreSQL 17 │  │
               │  │ (Images) │  │  (Database)  │  │
               │  └──────────┘  └──────────────┘  │
               └──────────────┬──────────────┬─────┘
                              │              │
              ┌───────────────▼──┐   ┌───────▼──────────┐
              │ Anthropic Claude │   │ Stripe/RevenueCat │
              │ (Vision + Chat)  │   │ (Payments)        │
              └──────────────────┘   └──────────────────┘
```

### Data Flow — Core Analysis Loop

```
1. App calls start_tool_session (RPC)
   → Validates palms + credits
   → Deducts credits
   → Creates tool_sessions row (status=pending)
   → Returns session_id

2. App calls POST /functions/v1/analyze-palm
   → Downloads palm images from Storage
   → Calls Claude Opus 4.6 (vision)
   → Writes results to tool_sessions, tool_session_metrics, session_solutions
   → Sets status=completed

3. Triggers fire automatically:
   → trg_init_action_progress: creates action plan rows
   → trg_notify_session_status: creates session_completed notification

4. App reads results via PostgREST
   → GET /rest/v1/tool_sessions?id=eq.<id>&select=*,...
```

### API Layers

| Layer | Path Prefix | Purpose |
|---|---|---|
| Supabase Auth | `/auth/v1/` | Registration, login, token refresh, OAuth |
| REST (PostgREST) | `/rest/v1/` | Table CRUD and RPC functions |
| Edge Functions | `/functions/v1/` | AI analysis, chat, payment webhooks |
| Storage | `/storage/v1/` | Palm image upload and signed URL retrieval |

---

## 3. Technology Stack

| Layer | Technology | Version / Notes |
|---|---|---|
| Frontend | FlutterFlow | No source in this repo |
| Backend platform | Supabase | PostgreSQL 17, PostgREST, Auth, Storage |
| Database | PostgreSQL | v17, hosted on Supabase |
| Edge runtime | Deno | v2 (Supabase Edge Functions) |
| AI — Palm Analysis | Anthropic Claude Opus 4.6 | Vision model; high reasoning quality |
| AI — Chat | Anthropic Claude Haiku 4.5 | Low latency, cost-efficient |
| Payment — Mobile | RevenueCat | iOS/Android in-app purchases |
| Payment — Web | Stripe | Card payments, webhook-driven |
| CLI tooling | Supabase CLI | Installed locally via npm (`npx supabase`) |
| SDK | `@supabase/supabase-js` | v2 — used in edge functions |
| SDK | `@anthropic-ai/sdk` | v0.78+ — used in edge functions |

---

## 4. Project Structure

```
palmyst/
├── CLAUDE.md                                # AI tooling project guidelines
├── BACKEND.md                               # Backend architecture reference
├── API.md                                   # Complete REST API reference (54 endpoints)
├── PROJECT_CORE_DOCUMENTATION.md            # This file — central knowledge hub
├── package.json                             # Node.js deps: supabase CLI, anthropic SDK
├── package-lock.json                        # Locked dependency tree
├── .env.local                               # Local secrets (NOT committed)
├── api.json                                 # Self-contained Postman collection
├── palmyst.postman_collection.json          # Postman collection (with env)
├── palmyst.postman_environment.json         # Postman environment variables
├── doc/
│   ├── db-schema.md                         # Full schema docs with ER diagram (Mermaid)
│   └── palmyst_app_figma_image_page-*.jpg   # Figma UI mockups (15 pages)
├── docs/
│   └── USAGE_GUIDE.md                       # Developer usage and testing guide
└── supabase/
    ├── config.toml                          # Local Supabase project config
    ├── seed.sql                             # Initial seed data
    ├── seeds/                               # Additional seed files
    ├── migrations/
    │   ├── 20260306142259_remote_schema.sql # Base extensions + RLS auto-enable trigger
    │   ├── 20260306200001_palmyst_schema.sql # All 23 tables, enums, indexes, RLS
    │   └── 20260310000001_backend_logic.sql  # Triggers, RPC functions, credit helpers
    └── functions/
        ├── _shared/
        │   ├── cors.ts                      # CORS headers + OPTIONS handler
        │   └── errors.ts                    # JSON and error response helpers
        ├── analyze-palm/
        │   └── index.ts                     # AI palm image analysis (Claude Opus 4.6)
        ├── chat/
        │   └── index.ts                     # Conversational assistant (Claude Haiku 4.5)
        └── process-payment/
            └── index.ts                     # Stripe & RevenueCat webhook handler
```

### Key Files Explained

| File | Purpose |
|---|---|
| `supabase/config.toml` | Configures local Supabase stack (ports, project_id = "palmyst") |
| `supabase/migrations/20260306142259_remote_schema.sql` | Extensions + DDL trigger that auto-enables RLS on all new public tables |
| `supabase/migrations/20260306200001_palmyst_schema.sql` | All 9 ENUMs, 23 tables, 32 indexes, RLS policies, `handle_new_user` trigger |
| `supabase/migrations/20260310000001_backend_logic.sql` | Credit helpers, 6 business triggers, 8 RPC functions |
| `supabase/functions/analyze-palm/index.ts` | Fetches palm images → Claude Opus 4.6 → writes structured results |
| `supabase/functions/chat/index.ts` | Context-aware chat with Claude Haiku 4.5, 20-message history |
| `supabase/functions/process-payment/index.ts` | HMAC-verified webhook handler for Stripe + RevenueCat |
| `supabase/seed.sql` | Languages, categories, tool creators, tools, plans (dev/test data) |

---

## 5. Database Design

### Entity Hierarchy

```
auth.users  (Supabase managed)
  └── profiles                    1:1 — credit_balance, preferred_language_id, referred_by
        ├── palms                  N per user; one is_self=true enforced by partial index
        ├── credit_transactions    Append-only audit ledger; balance_after on every row
        ├── user_purchases         Payment records; credits granted on completion
        ├── tool_sessions          AI analysis runs
        │     ├── tool_session_metrics    Percentage scores per life category (6 rows)
        │     ├── session_solutions       traditional / science_backed advice (2 rows)
        │     └── user_action_progress    Sequential action plan state
        ├── chat_sessions
        │     └── chat_messages
        ├── tool_reviews
        └── notifications

categories → tools → tool_features
tools → actionable_plans → plan_actions → action_steps
subscription_plans → user_purchases ← promo_codes
languages  (lookup)
banners    (CMS promotional content)
tool_creators → tools
```

### ENUM Types

| Type | Values |
|---|---|
| `gender_enum` | `male`, `female`, `other`, `prefer_not_to_say` |
| `session_status` | `pending`, `processing`, `completed`, `failed` |
| `solution_type` | `traditional`, `science_backed` |
| `action_status` | `locked`, `available`, `completed` |
| `reflection_feeling` | `felt_good`, `was_uncomfortable`, `not_sure_yet` |
| `message_role` | `user`, `assistant` |
| `credit_type` | `signup_bonus`, `tool_usage`, `tool_refund`, `solution_unlock`, `purchase`, `referral_bonus`, `review_reward`, `share_reward`, `admin_grant`, `promo_bonus` |
| `discount_type` | `percentage`, `fixed` |
| `payment_status` | `pending`, `completed`, `failed`, `refunded` |

### Tables Reference

| Table | Primary FK | Key Columns | Notes |
|---|---|---|---|
| `languages` | — | `code` (UNIQUE), `is_active`, `display_order` | Lookup table, no timestamps |
| `profiles` | `auth.users(id)` | `display_name`, `avatar_url`, `credit_balance`, `referred_by` | 1:1 with auth.users; created by trigger |
| `palms` | `profiles(id)` | `owner_id`, `name`, `age`, `gender`, `palm_image_url`, `is_self` | Partial unique index: one `is_self=true` per owner |
| `categories` | — | `slug` (UNIQUE), `icon_url`, `is_active`, `display_order` | Life category taxonomy |
| `tool_creators` | — | `name`, `avatar_url`, `bio` | Creator profiles linked to tools |
| `tools` | `categories(id)`, `tool_creators(id)` | `slug`, `credit_cost`, `min_palms_required`, `is_active`, `is_featured` | `min_palms_required` IN (1, 2) |
| `tool_features` | `tools(id)` | `title`, `description`, `display_order` | Marketing bullet points; no timestamps |
| `tool_sessions` | `profiles(id)`, `tools(id)`, `palms(id)` | `palm1_id`, `palm2_id`, `credits_used`, `status`, `overall_score`, `summary_text`, `result_data` | `result_data` is JSONB |
| `tool_session_metrics` | `tool_sessions(id)` | `metric_name`, `score`, `unit`, `display_order` | One row per life category |
| `session_solutions` | `tool_sessions(id)` | `solution_type`, `content`, `is_unlocked`, `credits_to_unlock`, `unlocked_at` | UNIQUE (session_id, solution_type) |
| `actionable_plans` | `tools(id)` | `title`, `description`, `total_actions` | Template plans per tool |
| `plan_actions` | `actionable_plans(id)` | `title`, `why_this_matters`, `what_you_can_do`, `display_order` | UNIQUE (plan_id, display_order) |
| `action_steps` | `plan_actions(id)` | `step_number`, `content` | Sub-steps of an action; no timestamps |
| `user_action_progress` | `profiles(id)`, `tool_sessions(id)`, `plan_actions(id)` | `status`, `reflection_feeling`, `reflection_notes`, `completed_at` | UNIQUE (user_id, session_id, action_id) |
| `chat_sessions` | `profiles(id)`, `tools(id)`, `tool_sessions(id)` | `title` | Optional link to tool_session for context enrichment |
| `chat_messages` | `chat_sessions(id)` | `role`, `content`, `is_liked` | `is_liked` is nullable tri-state (liked/disliked/unrated) |
| `credit_transactions` | `profiles(id)` | `amount`, `type`, `description`, `reference_id`, `reference_type`, `balance_after` | Append-only audit ledger |
| `subscription_plans` | — | `slug` (UNIQUE), `price_usd`, `credits_included`, `features` (JSONB), `is_active` | Credit bundle plans |
| `promo_codes` | — | `code` (UNIQUE), `discount_type`, `discount_value`, `max_uses`, `used_count`, `valid_from`, `valid_until`, `is_active` | Discount codes |
| `user_purchases` | `profiles(id)`, `subscription_plans(id)`, `promo_codes(id)` | `amount_paid`, `payment_status`, `payment_provider`, `payment_provider_ref`, `credits_granted` | Payment records |
| `tool_reviews` | `profiles(id)`, `tools(id)`, `tool_sessions(id)` | `rating` (1–5), `review_text`, `credits_earned` | UNIQUE (user_id, tool_id) |
| `banners` | `categories(id)`, `tools(id)` | `title`, `image_url`, `cta_action`, `is_active`, `valid_from`, `valid_until` | CMS-managed promotional content |
| `notifications` | `profiles(id)` | `title`, `body`, `type`, `is_read`, `reference_id`, `reference_type` | Polymorphic reference |

### Key Indexes

```sql
-- One self-palm per user (partial unique)
uq_palms_owner_is_self ON palms(owner_id) WHERE is_self = true

-- Session queries
idx_tool_sessions_user_id
idx_tool_sessions_status
idx_tool_sessions_created_at DESC

-- Notification unread badge count
idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false

-- Active banners ordered for display
idx_banners_active_order ON banners(display_order) WHERE is_active = true

-- Credit ledger
idx_credit_transactions_user_id
idx_credit_transactions_created_at DESC
```

### Design Decisions

- All PKs are `uuid` with `gen_random_uuid()`
- `set_updated_at()` trigger maintains `updated_at` on all mutable tables
- `profiles.credit_balance` is a denormalised cache; `credit_transactions.balance_after` allows reconstruction without sum
- `session_solutions.content` is always stored; the client enforces the lock UI — enforcement is also by the `unlock_solution` RPC
- `chat_messages.is_liked` uses `null` (not rated), `true` (liked), `false` (disliked)
- `banners` and `promo_codes` use time-window columns (`valid_from`, `valid_until`) for scheduling

---

## 6. Backend Logic

### Database Migrations

Migrations must be applied in filename order. **Never edit a committed migration** — always create a new file.

| File | Size | Purpose |
|---|---|---|
| `20260306142259_remote_schema.sql` | Small | Extensions + `rls_auto_enable` DDL event trigger |
| `20260306200001_palmyst_schema.sql` | ~1 100 lines | 9 ENUMs, 23 tables, 32 indexes, RLS policies |
| `20260310000001_backend_logic.sql` | ~790 lines | Credit helpers, 6 triggers, 8 RPC functions |

### Credit System

```
Earn                            Spend
──────────────────────────────────────────────────────────────
Signup bonus        +5          Tool analysis    −N (tool.credit_cost)
Referral bonus      +10         Solution unlock  −5 (per solution)
Review reward       +3
Share reward        +2 per 24h (rate-limited per tool)
Purchase            +N (per plan)
Admin grant         +N
──────────────────────────────────────────────────────────────
Auto-refund         +N when session fails (type = tool_refund)
```

#### Internal Credit Helpers (SECURITY DEFINER)

Both functions are revoked from `PUBLIC` and `authenticated`. Called exclusively from trigger functions and RPC functions.

**`internal_deduct_credits(user_id, amount, type, desc, ref_id?, ref_type?)`**
1. `UPDATE profiles SET credit_balance = credit_balance - amount WHERE id = user_id AND credit_balance >= amount`
2. If no row updated → raises `insufficient_credits` or `profile_not_found`
3. Inserts negative-amount row into `credit_transactions` with `balance_after`
4. The `WHERE credit_balance >= amount` makes this atomic — no separate check needed

**`internal_grant_credits(user_id, amount, type, desc, ref_id?, ref_type?)`**
1. `UPDATE profiles SET credit_balance = credit_balance + amount WHERE id = user_id`
2. If no row updated → raises `profile_not_found`
3. Inserts positive-amount row into `credit_transactions`

### Database Triggers

| Trigger | Function | Table | Event | Timing |
|---|---|---|---|---|
| `on_auth_user_created` | `handle_new_user` | `auth.users` | INSERT | AFTER |
| `trg_init_action_progress` | `fn_init_action_progress` | `tool_sessions` | UPDATE | AFTER |
| `trg_notify_session_status` | `fn_notify_session_status` | `tool_sessions` | UPDATE | AFTER |
| `trg_refund_on_failure` | `fn_refund_on_failure` | `tool_sessions` | UPDATE | AFTER |
| `trg_grant_credits_on_purchase` | `fn_grant_credits_on_purchase` | `user_purchases` | UPDATE | AFTER |
| `trg_increment_promo_usage` | `fn_increment_promo_usage` | `user_purchases` | INSERT | AFTER |
| `trg_review_credits` | `fn_grant_review_credits` | `tool_reviews` | INSERT | BEFORE |

#### handle_new_user
Fires on every new user registration via Supabase Auth.
1. Extracts `display_name` from OAuth metadata (`full_name` → `name` → email prefix)
2. Extracts `avatar_url` from OAuth metadata (`avatar_url` → `picture`)
3. Safely casts `referred_by` UUID from metadata; nulls on invalid input
4. Validates referrer profile exists; nulls if not found
5. Inserts `profiles` row with `credit_balance = 5`
6. Inserts `signup_bonus` credit transaction
7. If valid referrer: grants referrer +10 credits + `referral_bonus` notification

#### fn_init_action_progress
Fires when `tool_sessions.status` transitions to `completed`.
- Finds the tool's `actionable_plans` and all `plan_actions`
- Inserts `user_action_progress` rows: first action = `available`, rest = `locked`
- Uses `ON CONFLICT DO NOTHING` for idempotency

#### fn_notify_session_status
Fires on any `tool_sessions.status` change.
- `completed` → inserts `session_completed` notification
- `failed` → inserts `session_failed` notification

#### fn_refund_on_failure
Fires when `tool_sessions.status` transitions to `failed` from `pending` or `processing`.
- Calls `internal_grant_credits` with type `tool_refund` for `credits_used` amount
- `OLD.status IN ('pending', 'processing')` prevents double-refund

#### fn_grant_credits_on_purchase
Fires when `user_purchases.payment_status` transitions to `completed`.
- Calls `internal_grant_credits` with `credits_granted` amount
- Inserts `purchase_completed` notification

#### fn_increment_promo_usage
Fires on every INSERT to `user_purchases`. If `promo_code_id` is not null, increments `promo_codes.used_count` by 1.

#### fn_grant_review_credits
Fires BEFORE INSERT on `tool_reviews`.
- Sets `NEW.credits_earned = 3`
- Calls `internal_grant_credits` with type `review_reward`

### RPC Functions (8 total)

All callable via `POST /rest/v1/rpc/<function_name>`. All are `SECURITY DEFINER`, validate `auth.uid()` internally.

#### Error Convention

| Code | Meaning |
|---|---|
| `not_authenticated` | No valid JWT |
| `tool_not_found` | Tool does not exist or is inactive |
| `invalid_palm` | Palm missing or not owned by caller |
| `second_palm_required` | Tool requires 2 palms, only 1 provided |
| `insufficient_credits` | Not enough credits |
| `profile_not_found` | Profile row missing |
| `session_not_found` | Session missing or not owned by caller |
| `solution_not_found` | Solution type not yet generated |
| `invalid_rating` | Rating outside 1–5 |
| `progress_not_found` | Progress row missing or not owned |
| `action_locked` | Action not yet unlocked |
| `already_completed` | Action already completed |

#### start_tool_session
`start_tool_session(p_tool_id uuid, p_palm1_id uuid, p_palm2_id uuid = null) → uuid`

Validates tool, palms, and credits. Deducts credits. Creates `tool_sessions` row with `status = 'pending'`. Returns `session_id`. Must be followed immediately by `analyze-palm` edge function call.

#### unlock_solution
`unlock_solution(p_session_id uuid, p_solution_type solution_type) → json`

Idempotent. Returns content immediately if already unlocked. Otherwise deducts `credits_to_unlock` (5) and marks unlocked.

#### validate_promo_code
`validate_promo_code(p_code text) → json`

No auth required. Checks `is_active`, time window, and `used_count < max_uses`. Input is trimmed and uppercased. Does not consume the code.

#### submit_review
`submit_review(p_tool_id uuid, p_rating int, p_review_text text = null, p_session_id uuid = null) → json`

Supports upsert. Credits earned only on first submission (`trg_review_credits` fires on INSERT, not UPDATE).

#### advance_action
`advance_action(p_progress_id uuid, p_feeling reflection_feeling = null, p_notes text = null) → json`

Marks action as `completed`, records feeling/notes, unlocks next action by `display_order`. Returns `{completed, next, has_next}`.

#### mark_all_notifications_read
`mark_all_notifications_read() → int`

Returns count of rows updated.

#### record_share_reward
`record_share_reward(p_tool_id uuid) → json`

Grants +2 credits. Rate-limited: checks for a `share_reward` transaction with `reference_id = p_tool_id` in the last 24 hours. Returns `{rewarded: false, reason: "already_rewarded_today"}` if rate-limited.

#### get_my_credits
`get_my_credits() → json`

Returns `{balance, recent_transactions[20]}`.

### Edge Functions

All edge functions run on Deno 2 and handle CORS preflight via `_shared/cors.ts`.

#### analyze-palm

**Endpoint:** `POST /functions/v1/analyze-palm`
**Auth:** Bearer JWT
**Request:** `{"session_id": "uuid"}`
**Response:** `{"session_id": "uuid", "status": "completed"}`

**Flow:**
1. Verify JWT and create user-scoped + admin Supabase clients
2. Fetch `tool_sessions` row — verify ownership; status must be `pending` or `processing`
3. Update `status = 'processing'`
4. Fetch palm records and their `palm_image_url` values
5. Download images via `fetch()` and encode as base64
6. Send to Claude Opus 4.6 with structured system prompt + base64 image block(s)
7. Parse JSON response, validate required fields
8. Write via admin client (bypasses RLS):
   - `tool_sessions`: `status = 'completed'`, `overall_score`, `summary_text`, `result_data`
   - `tool_session_metrics`: 6 rows
   - `session_solutions`: 2 rows (`is_unlocked = false`, `credits_to_unlock = 5`)
9. On any error: `status = 'failed'` → `trg_refund_on_failure` auto-refunds credits

**Claude Output Schema:**
```json
{
  "overall_score": 75,
  "summary_text": "Your palm reveals...",
  "metrics": [
    {"metric_name": "Relationship", "score": 80, "unit": "%", "display_order": 1}
  ],
  "key_lines": {"heart_line": "...", "head_line": "...", "life_line": "...", "fate_line": "..."},
  "mounts": {"venus": "...", "jupiter": "...", "saturn": "...", "apollo": "...", "mercury": "..."},
  "detailed_analysis": "...",
  "traditional_advice": "...",
  "science_backed_advice": "..."
}
```

**Error Responses:**

| Status | Meaning |
|---|---|
| 401 | Missing Authorization header |
| 404 | Session not found |
| 409 | Session already in terminal state |
| 500 | Missing `ANTHROPIC_API_KEY` |
| 500 | AI analysis failed (credits auto-refunded) |

---

#### chat

**Endpoint:** `POST /functions/v1/chat`
**Auth:** Bearer JWT
**Request:** `{"chat_session_id": "uuid", "message": "string (max 2000 chars)"}`
**Response:** `{"message_id": "uuid", "content": "string", "created_at": "ISO"}`

**Flow:**
1. Validate chat session ownership via user-scoped client
2. Fetch last 20 `chat_messages` (ascending) for conversation history
3. If linked `tool_session_id` with status `completed`: enrich system prompt with `overall_score`, `summary_text`, `result_data`
4. Pre-save user message to `chat_messages`
5. Call Claude Haiku 4.5 with history + message
6. Save AI reply to `chat_messages`
7. Update `chat_sessions.updated_at`
8. On AI failure: delete pre-saved user message, return 500

**Model rationale:** Haiku 4.5 for chat (low latency, low cost); Opus 4.6 for analysis (high reasoning quality).

---

#### process-payment

**Endpoint:** `POST /functions/v1/process-payment`
**Auth:** HMAC-SHA256 webhook signature (no user JWT)
**Response:** `{"received": true, "processed": true, "purchase_id": "uuid"}`

**Provider Detection:**

| Header | Provider |
|---|---|
| `stripe-signature` | Stripe |
| `x-revenuecat-signature` | RevenueCat |
| Neither | 400 Bad Request |

**Stripe Signature:** Reconstructs `timestamp.rawBody` and compares HMAC-SHA256 against the `v1` value.
**RevenueCat Signature:** HMAC-SHA256 of `rawBody`, compared as base64.

**Supported Events:**

| Provider | Event | Status |
|---|---|---|
| Stripe | `payment_intent.succeeded` | `completed` |
| Stripe | `charge.refunded` | `refunded` |
| Stripe | Any other | `failed` |
| RevenueCat | `INITIAL_PURCHASE`, `RENEWAL`, `NON_SUBSCRIPTION_PURCHASE` | `completed` |
| RevenueCat | `CANCELLATION`, `EXPIRATION` | `refunded` |
| RevenueCat | Any other | `failed` |

**Flow:**
1. Read raw body (required for HMAC)
2. Detect provider and verify signature
3. Normalise payload to internal `NormalisedEvent` shape
4. Resolve `user_id` from metadata; fall back to email lookup via admin auth API
5. Lookup `subscription_plans` by `planSlug` for `credits_included`
6. Check `user_purchases` by `payment_provider_ref` for idempotency
7. INSERT or UPDATE `user_purchases` accordingly
8. `trg_grant_credits_on_purchase` fires automatically when `payment_status = 'completed'`

---

## 7. Authentication & Security

### Authentication Flow

Supabase Auth handles authentication. It issues JWTs (access tokens) valid for 1 hour with refresh tokens.

```
Sign Up: POST /auth/v1/signup
  → body: {email, password, data: {full_name, referred_by?}}
  → triggers handle_new_user() automatically
  → returns {access_token, refresh_token, user}

Sign In: POST /auth/v1/token?grant_type=password
  → body: {email, password}

Token Refresh: POST /auth/v1/token?grant_type=refresh_token
  → body: {refresh_token}

Sign Out: POST /auth/v1/logout
```

Supported OAuth providers: Google, Facebook (configured in Supabase Auth dashboard).

### Row Level Security (RLS)

RLS is enabled on all 23 tables. The `rls_auto_enable` DDL event trigger ensures new tables automatically get RLS enabled.

**Design principles:**
- Users can only read/write their own rows via `auth.uid() = user_id / owner_id`
- All credit mutations go through `SECURITY DEFINER` functions — no direct INSERT/UPDATE policy on `credit_transactions`
- AI result write-back uses the service role key (edge functions bypass RLS)
- Payment status updates use the service role (webhook handler)
- Public catalogues (`categories`, `tools`, `languages`, `subscription_plans`) are read-only for all authenticated users

**RLS Policy Matrix:**

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `profiles` | Own row | Via trigger only | Own row | Via cascade |
| `palms` | Own | Own | Own | Own |
| `tool_sessions` | Own | Own | service_role only | service_role only |
| `tool_session_metrics` | Own (via session) | service_role only | — | — |
| `session_solutions` | Own (via session) | service_role only | Own (via session) | — |
| `user_action_progress` | Own | Own | Own | — |
| `chat_sessions` | Own | Own | Own | Own |
| `chat_messages` | Own (via session) | Own (via session) | — | Own (via session) |
| `credit_transactions` | Own | service_role only | — | — |
| `user_purchases` | Own | Own | service_role only | — |
| `tool_reviews` | All authenticated | Own | Own | Own |
| `notifications` | Own | service_role only | Own (`is_read` only) | — |
| `languages` | Active rows | — | — | — |
| `categories` | Active rows | — | — | — |
| `tool_creators` | All | — | — | — |
| `tools` | Active rows | — | — | — |
| `tool_features` | All | — | — | — |
| `actionable_plans` | All | — | — | — |
| `plan_actions` | All | — | — | — |
| `action_steps` | All | — | — | — |
| `subscription_plans` | Active rows | — | — | — |
| `promo_codes` | Active + valid window | — | — | — |
| `banners` | Active + valid window | — | — | — |

### Security Practices

- **SECURITY DEFINER** on all RPC functions: run as DB owner, validate `auth.uid()` internally
- **REVOKE ALL** on internal credit helpers from `PUBLIC` — only triggers and RPCs can call them
- **HMAC-SHA256** signature verification on payment webhooks — no unauthenticated writes
- **Atomic balance checks**: `WHERE credit_balance >= amount` in a single UPDATE eliminates race conditions
- **No default ENV values** in code — all secrets must be explicitly configured
- **Partial index** on `palms(owner_id) WHERE is_self = true` — database-enforced one-self-palm rule

---

## 8. External Integrations

### Anthropic Claude

| Use Case | Model | Reason |
|---|---|---|
| Palm image analysis | Claude Opus 4.6 | Highest vision reasoning quality |
| Conversational chat | Claude Haiku 4.5 | Low latency and cost for conversational turns |

The `@anthropic-ai/sdk` v0.78+ is used in edge functions. The API key is set as `ANTHROPIC_API_KEY` in Supabase secrets.

**analyze-palm** sends:
- System prompt specifying structured JSON output schema with all required fields
- One or two base64-encoded palm images as vision blocks
- User prompt with palm owner names, age, gender, and tool focus area

**chat** sends:
- System prompt (optionally enriched with palm reading results)
- Last 20 messages as conversation history
- Current user message

### Stripe

- Used for web/card payments
- Webhook URL: `https://<project-ref>.supabase.co/functions/v1/process-payment`
- Events to subscribe: `payment_intent.succeeded`, `charge.refunded`
- Metadata required: `supabase_user_id`, `plan_slug` (matching `subscription_plans.slug`)
- Secret: `STRIPE_WEBHOOK_SECRET` (signing secret from Stripe Dashboard → Webhooks)

### RevenueCat

- Used for iOS/Android in-app purchases
- Webhook URL: `https://<project-ref>.supabase.co/functions/v1/process-payment`
- Custom product metadata required: `supabase_user_id`, `plan_slug`
- Secret: `REVENUECAT_WEBHOOK_SECRET`

### Supabase Storage

Palm images are stored in a `palms` bucket.

```
Upload:   POST /storage/v1/object/palms/<user_id>/<filename>.jpg
Signed:   POST /storage/v1/object/sign/palms/<path>  (body: {"expiresIn": 3600})
```

Images are uploaded first, then the `palm_image_url` is set on the `palms` record separately.

---

## 9. Environment Configuration

### Edge Function Secrets

Configure in Supabase Dashboard → Project Settings → Edge Functions → Manage Secrets.

| Variable | Required By | Source |
|---|---|---|
| `ANTHROPIC_API_KEY` | `analyze-palm`, `chat` | console.anthropic.com |
| `STRIPE_WEBHOOK_SECRET` | `process-payment` | Stripe Dashboard → Webhooks |
| `REVENUECAT_WEBHOOK_SECRET` | `process-payment` | RevenueCat Dashboard → Project Settings |
| `SUPABASE_URL` | All functions | Auto-injected by runtime |
| `SUPABASE_ANON_KEY` | `analyze-palm`, `chat` | Auto-injected by runtime |
| `SUPABASE_SERVICE_ROLE_KEY` | All functions | Auto-injected by runtime |

The three `SUPABASE_*` variables are automatically injected and do not need manual configuration.

### Local Development (.env.local)

```
ANTHROPIC_API_KEY=sk-ant-...
STRIPE_WEBHOOK_SECRET=whsec_...
REVENUECAT_WEBHOOK_SECRET=...
```

This file is not committed to git.

### config npm package

The project uses the `config` npm package for configuration management. No default values for ENVs should be set in code — any defaults must come from `default.json` in the config directory.

### supabase/config.toml

Local Supabase project configuration:
- `project_id = "palmyst"`
- PostgreSQL 17
- API port: 54321
- Database port: 54322
- Studio port: 54323

---

## 10. Development Workflow

### Prerequisites

- Docker Desktop (running)
- Node.js (for `npx`)
- Run `npm install` in project root to get Supabase CLI

### Starting Local Development

```bash
# Start local Supabase stack (Docker required)
npx supabase start

# Apply all migrations and seed data from scratch
npx supabase db reset --local

# Serve edge functions locally with secrets
npx supabase functions serve --env-file .env.local
```

### Local Service URLs

| Service | URL |
|---|---|
| API / PostgREST | http://127.0.0.1:54321 |
| Supabase Studio | http://127.0.0.1:54323 |
| PostgreSQL | postgresql://postgres:postgres@127.0.0.1:54322/postgres |
| Email testing (Inbucket) | http://127.0.0.1:54324 |
| Analytics | http://127.0.0.1:54327 |

### Testing APIs

Two Postman collections are provided:

**api.json** — Self-contained (recommended for quick testing)
- Import directly into Postman
- Contains all 54 endpoints
- Pre-request scripts add the `apikey` header automatically
- Test scripts auto-populate variables (e.g. `auth_token` after sign in)

**palmyst.postman_collection.json + palmyst.postman_environment.json** — Paired files
- Import both into Postman
- Set `base_url` and `anon_key` in the environment before testing

**Required Postman variables:**

| Variable | Description |
|---|---|
| `base_url` | `http://127.0.0.1:54321` (local) or production URL |
| `anon_key` | Supabase anon/public key |
| `auth_token` | JWT access token (auto-set after sign in) |
| `user_id` | UUID of authenticated user |
| `palm_id` | UUID of a palm record |
| `tool_id` | UUID of a tool |
| `session_id` | UUID of a tool session |
| `chat_session_id` | UUID of a chat session |

### Testing Edge Functions Locally

```bash
# Sign in to get a JWT
TOKEN=$(curl -s -X POST http://127.0.0.1:54321/auth/v1/token?grant_type=password \
  -H "apikey: <anon_key>" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Password123!"}' | jq -r .access_token)

# Analyze palm
curl -X POST http://127.0.0.1:54321/functions/v1/analyze-palm \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"session_id": "<uuid>"}'

# Chat
curl -X POST http://127.0.0.1:54321/functions/v1/chat \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"chat_session_id": "<uuid>", "message": "What does my heart line mean?"}'
```

### Creating a New Migration

Only create a new migration when the previous one is committed to git and pushed to the server.

```bash
# Generate from schema diff (after making changes in Supabase Studio)
npx supabase db diff -f <migration_name>

# Or create manually
touch supabase/migrations/$(date +%Y%m%d%H%M%S)_description.sql
```

**Rules:**
- Never edit a migration that is already committed to git
- Never edit a migration that has been pushed to production
- Always use `--local` flag when targeting local setup

### Stop Local Stack

```bash
npx supabase stop
```

---

## 11. Deployment Architecture

### Production Stack

The production environment runs on Supabase cloud infrastructure:
- **Database:** Supabase-managed PostgreSQL 17
- **API:** PostgREST (auto-generated from schema)
- **Auth:** Supabase Auth service
- **Storage:** Supabase Storage (S3-compatible)
- **Edge Functions:** Deployed to Supabase Deno runtime (global edge network)

### Deploying Migrations

```bash
# Link local project to production
npx supabase link --project-ref <project-ref>

# Push pending migrations to production
npx supabase db push

# Verify migration status
npx supabase db remote commit
```

### Deploying Edge Functions

```bash
npx supabase functions deploy analyze-palm
npx supabase functions deploy chat
npx supabase functions deploy process-payment
```

### Configuring Production Secrets

Navigate to: Supabase Dashboard → Project Settings → Edge Functions → Manage Secrets

```
ANTHROPIC_API_KEY         = sk-ant-...
STRIPE_WEBHOOK_SECRET     = whsec_...
REVENUECAT_WEBHOOK_SECRET = ...
```

### Configuring Payment Webhooks

**Stripe:**
1. Dashboard → Developers → Webhooks → Add endpoint
2. URL: `https://<project-ref>.supabase.co/functions/v1/process-payment`
3. Subscribe to: `payment_intent.succeeded`, `charge.refunded`
4. Copy signing secret → set as `STRIPE_WEBHOOK_SECRET`

**RevenueCat:**
1. Dashboard → Project Settings → Webhooks → Add webhook
2. URL: `https://<project-ref>.supabase.co/functions/v1/process-payment`
3. Copy webhook key → set as `REVENUECAT_WEBHOOK_SECRET`
4. Add product metadata: `supabase_user_id` and `plan_slug` (must match `subscription_plans.slug`)

---

## 12. Key Concepts & Business Logic

### Full API Reference (54 Endpoints)

| # | Method | Path | Auth | Description |
|---|---|---|---|---|
| 1 | POST | `/auth/v1/signup` | anon | Register user |
| 2 | POST | `/auth/v1/token?grant_type=password` | anon | Sign in |
| 3 | POST | `/auth/v1/token?grant_type=refresh_token` | anon | Refresh token |
| 4 | GET | `/auth/v1/user` | JWT | Get current user |
| 5 | PUT | `/auth/v1/user` | JWT | Update user |
| 6 | POST | `/auth/v1/logout` | JWT | Sign out |
| 7 | POST | `/auth/v1/recover` | anon | Password reset email |
| 8 | GET | `/rest/v1/profiles` | JWT | Get my profile |
| 9 | PATCH | `/rest/v1/profiles?id=eq.*` | JWT | Update profile |
| 10 | GET | `/rest/v1/palms` | JWT | List my palms |
| 11 | GET | `/rest/v1/palms?id=eq.*` | JWT | Get palm by ID |
| 12 | POST | `/rest/v1/palms` | JWT | Create palm |
| 13 | PATCH | `/rest/v1/palms?id=eq.*` | JWT | Update palm |
| 14 | DELETE | `/rest/v1/palms?id=eq.*` | JWT | Delete palm |
| 15 | GET | `/rest/v1/categories` | JWT | List active categories |
| 16 | GET | `/rest/v1/languages` | JWT | List active languages |
| 17 | GET | `/rest/v1/tool_creators` | JWT | List tool creators |
| 18 | GET | `/rest/v1/tools` | JWT | List active tools |
| 19 | GET | `/rest/v1/tools?is_featured=eq.true` | JWT | Featured tools |
| 20 | GET | `/rest/v1/tools?id=eq.*` | JWT | Get tool detail |
| 21 | GET | `/rest/v1/tools?category_id=eq.*` | JWT | Tools by category |
| 22 | GET | `/rest/v1/tool_features?tool_id=eq.*` | JWT | Tool features |
| 23 | POST | `/rest/v1/rpc/start_tool_session` | JWT | Start session |
| 24 | GET | `/rest/v1/tool_sessions` | JWT | List my sessions |
| 25 | GET | `/rest/v1/tool_sessions?id=eq.*` | JWT | Session detail |
| 26 | GET | `/rest/v1/tool_session_metrics?session_id=eq.*` | JWT | Session metrics |
| 27 | GET | `/rest/v1/session_solutions?session_id=eq.*` | JWT | Session solutions |
| 28 | POST | `/rest/v1/rpc/unlock_solution` | JWT | Unlock solution |
| 29 | GET | `/rest/v1/actionable_plans?tool_id=eq.*` | JWT | Plan for tool |
| 30 | GET | `/rest/v1/plan_actions?plan_id=eq.*` | JWT | Plan actions |
| 31 | GET | `/rest/v1/user_action_progress?session_id=eq.*` | JWT | Action progress |
| 32 | POST | `/rest/v1/rpc/advance_action` | JWT | Complete action |
| 33 | GET | `/rest/v1/chat_sessions` | JWT | List chat sessions |
| 34 | POST | `/rest/v1/chat_sessions` | JWT | Create chat session |
| 35 | DELETE | `/rest/v1/chat_sessions?id=eq.*` | JWT | Delete chat session |
| 36 | GET | `/rest/v1/chat_messages?chat_session_id=eq.*` | JWT | Get messages |
| 37 | PATCH | `/rest/v1/chat_messages?id=eq.*` | JWT | Like/dislike message |
| 38 | POST | `/rest/v1/rpc/get_my_credits` | JWT | Credit balance + history |
| 39 | POST | `/rest/v1/rpc/record_share_reward` | JWT | Share reward |
| 40 | GET | `/rest/v1/tool_reviews?tool_id=eq.*` | JWT | Tool reviews |
| 41 | POST | `/rest/v1/rpc/submit_review` | JWT | Submit review |
| 42 | GET | `/rest/v1/subscription_plans` | JWT | Subscription plans |
| 43 | POST | `/rest/v1/rpc/validate_promo_code` | JWT | Validate promo code |
| 44 | GET | `/rest/v1/user_purchases` | JWT | My purchases |
| 45 | GET | `/rest/v1/notifications` | JWT | All notifications |
| 46 | GET | `/rest/v1/notifications?is_read=eq.false` | JWT | Unread only |
| 47 | PATCH | `/rest/v1/notifications?id=eq.*` | JWT | Mark notification read |
| 48 | POST | `/rest/v1/rpc/mark_all_notifications_read` | JWT | Mark all read |
| 49 | GET | `/rest/v1/banners` | JWT | Active banners |
| 50 | POST | `/functions/v1/analyze-palm` | JWT | AI palm analysis |
| 51 | POST | `/functions/v1/chat` | JWT | Chat message |
| 52 | POST | `/functions/v1/process-payment` | HMAC | Payment webhook |
| 53 | POST | `/storage/v1/object/palms/*` | JWT | Upload palm image |
| 54 | POST | `/storage/v1/object/sign/palms/*` | JWT | Get signed URL |

### Standard Request Headers

```
apikey: <supabase-anon-key>                    # Every request
Authorization: Bearer <jwt-access-token>       # Authenticated requests
Content-Type: application/json                 # Mutation requests
Prefer: return=representation                  # Get created/updated row back
Accept: application/vnd.pgrst.object+json      # Get single object instead of array
```

### HTTP Status Codes

| Code | Meaning |
|---|---|
| 200 | Success (RPC, GET) |
| 201 | Created (POST with `Prefer: return=representation`) |
| 204 | No content (DELETE, PATCH without Prefer) |
| 400 | Bad request / validation error |
| 401 | Missing or invalid JWT |
| 403 | RLS denied access |
| 404 | Row not found |
| 409 | Conflict (unique constraint) |
| 422 | Unprocessable entity |

### Business Flow: User Signup & Referral

```
1. App calls POST /auth/v1/signup
   body: {email, password, data: {full_name, referred_by?: "<referrer_profile_id>"}}
2. Supabase Auth creates auth.users row
3. on_auth_user_created trigger fires handle_new_user()
   → profiles row created with credit_balance = 5
   → signup_bonus credit transaction inserted
   → if referred_by: referrer gets +10 credits + referral_bonus notification
4. App receives {access_token, refresh_token, user}
```

### Business Flow: Tool Session Lifecycle

```
App: call start_tool_session (RPC)
  → validate tool (is_active), palms (owned by caller), credits
  → deduct credits (internal_deduct_credits)
  → INSERT tool_sessions {status: 'pending', credits_used: N}
  ← return session_id (UUID)

App: call POST /functions/v1/analyze-palm {session_id}
  → status = 'processing'
  → download palm images from Storage
  → Claude Opus 4.6 vision API call
  → parse structured JSON response
  → UPDATE tool_sessions {status: 'completed', overall_score, summary_text, result_data}
  → INSERT tool_session_metrics (6 rows)
  → INSERT session_solutions (2 rows, is_unlocked=false)

  [trg_init_action_progress fires automatically]
    → INSERT user_action_progress: first=available, rest=locked

  [trg_notify_session_status fires automatically]
    → INSERT notification {type: 'session_completed'}

  IF any error:
    → UPDATE tool_sessions {status: 'failed'}
    [trg_refund_on_failure fires]
      → internal_grant_credits (tool_refund, credits_used amount)
    [trg_notify_session_status fires]
      → INSERT notification {type: 'session_failed'}

← {session_id, status: "completed"}
```

### Business Flow: Solution Unlock

```
App: call unlock_solution (RPC) {p_session_id, p_solution_type: "traditional"}
  → verify session is completed and owned by caller
  → if already is_unlocked=true: return content immediately (idempotent)
  → verify caller has credits_to_unlock (5) credits
  → internal_deduct_credits (solution_unlock)
  → UPDATE session_solutions {is_unlocked: true, unlocked_at: now()}
← {id, content, is_unlocked: true, unlocked_at}
```

### Business Flow: Action Plan Progress

```
Session completes → trg_init_action_progress creates:
  Progress 1: status=available
  Progress 2: status=locked
  Progress 3: status=locked

App: advance_action(progress_id_1, feeling="felt_good", notes="...")
  → Action 1: status=completed, records feeling/notes, completed_at
  → Action 2: status=available
← {completed: uuid1, next: uuid2, has_next: true}

App: advance_action(progress_id_2)
  → Action 2: completed, Action 3: available
← {completed: uuid2, next: uuid3, has_next: true}

App: advance_action(progress_id_3)
  → Action 3: completed, no more actions
← {completed: uuid3, next: null, has_next: false}
```

### Business Flow: Purchase & Credit Grant

```
App → Payment SDK (Stripe/RevenueCat)
Payment succeeds
Provider → POST /functions/v1/process-payment (webhook)
  → verify HMAC signature
  → normalise provider payload to NormalisedEvent
  → resolve user_id from metadata (supabase_user_id) or email lookup
  → lookup subscription_plans by plan_slug → credits_included
  → check user_purchases by payment_provider_ref (idempotency)
  → INSERT/UPDATE user_purchases {payment_status: 'completed', credits_granted: N}

[trg_grant_credits_on_purchase fires automatically]
  → internal_grant_credits (purchase, N credits)
  → INSERT notification {type: 'purchase_completed'}
← {received: true, processed: true, purchase_id: uuid}
```

### Business Flow: Chat Conversation

```
App: POST /rest/v1/chat_sessions {user_id, tool_session_id?, title}
← chat_session created

App: POST /functions/v1/chat {chat_session_id, message}
  → verify session ownership
  → fetch last 20 messages as history
  → if tool_session_id and session is completed:
       enrich system prompt with overall_score, summary_text, result_data
  → INSERT user message to chat_messages
  → Claude Haiku 4.5 API call with history + message
  → INSERT AI reply to chat_messages
  → UPDATE chat_sessions.updated_at
← {message_id, content, created_at}
```

### Seed Data

The following data is seeded on `npx supabase db reset --local`:
- **8 Languages:** English, Arabic, French, Spanish, German, Chinese Simplified, Japanese, Portuguese
- **6 Categories:** Relationship, Finance, Career, Health, Growth, Personal Life
- **4 Tool Creators:** Dr. Luna Silva, Master Chen Wei, Prof. Aria Patel, Dr. James Okonkwo
- **12+ Tools:** Love Path Reading, Life Path Compass, Career Clarity, Financial Insights, Health & Vitality, Personal Growth Accelerator, etc.
- **3 Subscription Plans:** Basic (~50 credits), Standard (~120 credits), Premium (~300 credits)
- **Actionable Plans:** 3 sequential actions per tool

---

## 13. Troubleshooting

### Edge Function: "AI service not configured"

**Error:** `500 — AI service not configured`
**Cause:** `ANTHROPIC_API_KEY` is missing from the environment.
**Fix (local):** Ensure `.env.local` contains `ANTHROPIC_API_KEY=sk-ant-...` and run `npx supabase functions serve --env-file .env.local`
**Fix (production):** Add `ANTHROPIC_API_KEY` in Supabase Dashboard → Project Settings → Edge Functions → Manage Secrets

---

### Edge Function: "Analysis failed. Credits have been refunded."

**Error:** `500` from `analyze-palm`
**Cause:** Claude API call failed or returned malformed JSON.
**Behaviour:** Credits are automatically refunded via `trg_refund_on_failure`. No manual intervention needed.
**Debugging:** Check Supabase Edge Function logs in the Dashboard.

---

### RPC Error: "insufficient_credits"

**Error:** `{"message": "insufficient_credits"}`
**Cause:** User's `credit_balance` is less than the tool's `credit_cost`.
**Fix:** User must purchase more credits or earn them via reviews/shares/referrals.

---

### Payment Webhook: Signature Verification Failure

**Error:** `401` from `process-payment`
**Cause:** `STRIPE_WEBHOOK_SECRET` or `REVENUECAT_WEBHOOK_SECRET` is incorrect or missing.
**Fix:**
- Verify the secret matches exactly what is shown in the provider dashboard
- Ensure the raw body is read before parsing (required for HMAC computation)
- Check that the correct header name is being sent by the provider

---

### Migration: "relation already exists"

**Cause:** Trying to apply a migration that has already been applied.
**Fix:** Check migration status with `npx supabase db remote commit`. Never re-run applied migrations; create a new migration file instead.

---

### Local Stack: Docker not running

**Error:** `Error: Cannot connect to the Docker daemon`
**Fix:** Start Docker Desktop before running `npx supabase start`.

---

### PostgREST: 403 Forbidden

**Cause:** RLS policy is blocking the request.
**Common cases:**
- Accessing another user's data (correct — expected behaviour)
- Trying to write to a service-role-only table directly (e.g. `credit_transactions`)
- Using the anon key without a valid JWT on an authenticated endpoint
**Fix:** Ensure `Authorization: Bearer <jwt>` header is present and valid. Use RPC functions for operations that require elevated privileges.

---

### RPC Error: "session_not_found"

**Cause:** The session either does not exist, is not owned by the calling user, or its status is not `completed` (for `unlock_solution`).
**Fix:** Verify the `session_id` belongs to the authenticated user and that analysis has completed successfully.

---

### Chat: Message Deleted on Failure

**Behaviour:** If Claude Haiku fails to respond, the pre-saved user message is deleted from `chat_messages`.
**Reason:** This keeps the conversation state clean and allows the user to retry without orphaned messages.

---

### Promo Code: "invalid_or_expired"

**Cause:** The code does not exist, is inactive, is outside its valid time window, or has reached `max_uses`.
**Fix:** Check `promo_codes` table in Studio. The code is trimmed and uppercased before lookup — ensure the code format matches.

---

### Double Credit Deduction (Race Condition)

This cannot happen. The `internal_deduct_credits` function uses a single `UPDATE ... WHERE credit_balance >= amount`. PostgreSQL's row-level locking makes this atomic. No separate balance check is performed.
