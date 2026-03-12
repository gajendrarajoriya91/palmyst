# Palmyst — Backend Workflow Documentation

> Generated: 2026-03-12 | Stack: Supabase (PostgreSQL 17) · Deno Edge Functions · Anthropic Claude · Stripe · RevenueCat

---

## Table of Contents

1. [Backend System Overview](#1-backend-system-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [API Request Lifecycle](#3-api-request-lifecycle)
4. [API Endpoints Workflow](#4-api-endpoints-workflow)
5. [Backend Function Execution Flow](#5-backend-function-execution-flow)
6. [Database Workflow](#6-database-workflow)
7. [Background Processes and Triggers](#7-background-processes-and-triggers)
8. [External Service Integration](#8-external-service-integration)
9. [Error Handling and Recovery Logic](#9-error-handling-and-recovery-logic)
10. [Data Flow Through the System](#10-data-flow-through-the-system)

---

## 1. Backend System Overview

Palmyst is a palm-reading and self-discovery mobile application. Users upload palm photos that are analysed by AI (Anthropic Claude) to generate insights across six life categories: **Relationship, Finance, Career, Health, Growth, and Personal Life**.

**Responsibilities of the backend:**

| Layer | Technology | Responsibility |
|---|---|---|
| Database | PostgreSQL 17 (Supabase) | All persistent data; 23 tables with strict RLS |
| Auth | Supabase Auth (JWT) | Identity, session tokens, signup triggers |
| Business Logic | SQL triggers + RPC functions | Credits, refunds, notifications, action plans |
| Edge Functions | Deno (TypeScript) | AI analysis, chat, payment webhooks |
| AI Analysis | Anthropic Claude Opus 4.6 | Palm image reading and insight generation |
| AI Chat | Anthropic Claude Haiku 4.5 | Context-aware conversational assistant |
| Payments | Stripe + RevenueCat webhooks | Credit pack purchases |
| Storage | Supabase Storage | Palm image file hosting |
| REST API | PostgREST (auto-generated) | CRUD operations on all tables |

The backend is **serverless by design**: there is no persistent application server. Every request is handled either by PostgREST (auto-generated REST from schema), an RPC function (a PostgreSQL function callable via REST), or a Deno Edge Function.

---

## 2. High-Level Architecture

### System Architecture Diagram

```mermaid
graph TB
    subgraph Client ["Client (FlutterFlow Mobile App)"]
        APP[Flutter App]
    end

    subgraph Supabase ["Supabase Platform"]
        direction TB
        GATEWAY[API Gateway<br/>Kong]
        AUTH[Auth Service<br/>/auth/v1]
        PGREST[PostgREST<br/>/rest/v1]
        STORAGE[Storage<br/>/storage/v1]

        subgraph EdgeFunctions ["Edge Functions (Deno Runtime)"]
            EF_PALM[analyze-palm]
            EF_CHAT[chat]
            EF_PAY[process-payment]
        end

        subgraph PostgreSQL ["PostgreSQL 17"]
            direction TB
            SCHEMA[23 Tables + RLS]
            TRIGGERS[6 Trigger Functions]
            RPC[8 RPC Functions]
        end
    end

    subgraph External ["External Services"]
        CLAUDE_OPUS[Claude Opus 4.6<br/>Palm Analysis]
        CLAUDE_HAIKU[Claude Haiku 4.5<br/>Chat]
        STRIPE[Stripe<br/>Webhooks]
        REVENUECAT[RevenueCat<br/>Webhooks]
    end

    APP -->|JWT + apikey| GATEWAY
    GATEWAY --> AUTH
    GATEWAY --> PGREST
    GATEWAY --> STORAGE
    GATEWAY --> EdgeFunctions

    PGREST --> SCHEMA
    PGREST --> RPC
    EdgeFunctions --> SCHEMA
    EdgeFunctions --> TRIGGERS

    EF_PALM -->|Claude API| CLAUDE_OPUS
    EF_CHAT -->|Claude API| CLAUDE_HAIKU
    STRIPE -->|webhook POST| EF_PAY
    REVENUECAT -->|webhook POST| EF_PAY

    TRIGGERS --> SCHEMA
```

### Component Interactions

```mermaid
graph LR
    subgraph Data Flow
        A[FlutterFlow] -->|REST /rest/v1| B[PostgREST]
        A -->|RPC /rest/v1/rpc| C[PostgreSQL Functions]
        A -->|Edge /functions/v1| D[Deno Edge Functions]
        B --> E[(PostgreSQL)]
        C --> E
        D --> E
        D --> F[Anthropic Claude API]
    end

    subgraph Automated
        E -->|INSERT/UPDATE trigger| G[Trigger Functions]
        G --> E
    end
```

---

## 3. API Request Lifecycle

Every API call from the FlutterFlow app passes through the same Supabase gateway and follows this lifecycle:

### Standard REST Request Flow

```mermaid
sequenceDiagram
    participant App as FlutterFlow App
    participant GW as Supabase Gateway (Kong)
    participant Auth as Auth Service
    participant PG as PostgREST / RPC
    participant DB as PostgreSQL + RLS
    participant TR as Trigger Functions

    App->>GW: HTTP request<br/>Headers: apikey + Authorization: Bearer JWT
    GW->>Auth: Validate JWT signature
    Auth-->>GW: User context (uid, role)
    GW->>PG: Forward with auth context
    PG->>DB: Execute SQL with auth.uid() set
    DB->>DB: RLS policy evaluation<br/>(reject if auth.uid() ≠ row owner)
    DB-->>PG: Result rows
    DB--)TR: Fire triggers (if INSERT/UPDATE)
    TR->>DB: Cascade writes (credits, notifications)
    PG-->>GW: JSON response
    GW-->>App: HTTP response (200 / 4xx / 5xx)
```

### Step-by-Step Breakdown

| Step | Location | What Happens |
|---|---|---|
| 1. Request Received | Kong Gateway | Validates `apikey` header. Rejects if missing. |
| 2. JWT Verification | Supabase Auth | Decodes Bearer token, extracts `auth.uid()` and `role`. Unauthenticated = `anon` role. |
| 3. Route Dispatch | Kong | Routes to PostgREST (`/rest/v1`), Auth (`/auth/v1`), Storage (`/storage/v1`), or Edge Function (`/functions/v1`). |
| 4. RLS Evaluation | PostgreSQL | Every SQL statement evaluated against RLS policies. `auth.uid()` must match `user_id` on user-owned rows. |
| 5. Business Logic | SQL / Edge Function | CRUD or RPC function executes. Edge functions run custom Deno code. |
| 6. Trigger Cascade | PostgreSQL | Triggers fire automatically on INSERT/UPDATE (credits, notifications, plan init). |
| 7. Response | PostgREST / Edge Function | Serialised JSON returned to client. |

### Edge Function Request Flow

```mermaid
sequenceDiagram
    participant App as FlutterFlow App
    participant GW as Supabase Gateway
    participant EF as Deno Edge Function
    participant DB as PostgreSQL
    participant AI as Anthropic Claude

    App->>GW: POST /functions/v1/<name><br/>Authorization: Bearer JWT
    GW->>EF: Invoke with JWT in headers
    EF->>EF: handleCors() — return 204 for OPTIONS
    EF->>DB: Validate session ownership<br/>(supabase.auth.getUser)
    DB-->>EF: User context
    EF->>DB: Fetch related data
    DB-->>EF: Data payload
    EF->>AI: POST to Anthropic API<br/>(base64 images or messages)
    AI-->>EF: Structured JSON response
    EF->>DB: Write results atomically
    EF-->>App: jsonResponse({...})
```

---

## 4. API Endpoints Workflow

### Base URLs

| Environment | URL |
|---|---|
| Local | `http://127.0.0.1:54321` |
| Production | `https://<project-ref>.supabase.co` |

### Standard Request Headers

```
apikey: <supabase-anon-key>
Authorization: Bearer <jwt-access-token>     # all authenticated requests
Content-Type: application/json               # mutations
Prefer: return=representation                # to get back the created/updated record
```

---

### 4.1 Authentication Endpoints (`/auth/v1`)

These are handled entirely by Supabase Auth — no custom code.

#### Sign Up
```
POST /auth/v1/signup
Body: { email, password, data: { full_name?, referred_by? } }
```

**Internal Flow:**
1. Supabase Auth creates `auth.users` row.
2. `handle_new_user()` trigger fires (AFTER INSERT on `auth.users`).
3. Trigger creates a `profiles` row with `credit_balance = 5` (welcome bonus).
4. If `referred_by` UUID provided and valid: grants 10 credits to the referrer + sends referrer a notification.
5. Returns: `{ access_token, refresh_token, user }`.

#### Sign In
```
POST /auth/v1/token?grant_type=password
Body: { email, password }
```
Returns JWT `access_token` (1 hour TTL) and `refresh_token` (long-lived).

#### Token Refresh
```
POST /auth/v1/token?grant_type=refresh_token
Body: { refresh_token }
```

---

### 4.2 Profile Endpoints (`/rest/v1/profiles`)

#### Get My Profile
```
GET /rest/v1/profiles?select=*&id=eq.<user_id>
```
RLS: Only own row visible (`auth.uid() = id`).

Returns: `credit_balance`, `preferred_language_id`, `referred_by`, `created_at`, etc.

#### Update Profile
```
PATCH /rest/v1/profiles?id=eq.<user_id>
Body: { full_name?, avatar_url?, preferred_language_id?, ... }
```
Triggers `set_updated_at()` automatically.

---

### 4.3 Palm Endpoints (`/rest/v1/palms`)

#### Create Palm
```
POST /rest/v1/palms
Body: { owner_id, label, image_url, is_self, gender, date_of_birth, hand_type }
```

**Constraints enforced by DB:**
- `is_self = true` is unique per `owner_id` (partial unique index).
- `image_url` must point to Supabase Storage.

#### Upload Palm Image (Storage)
```
POST /storage/v1/object/palm-images/<user_id>/<filename>
Body: binary image (JPEG/PNG/GIF/WebP)
```
Returns: `{ Key }` — used as `image_url` in the palm record.

---

### 4.4 Tool Session Workflow

This is the **core business flow**. It spans 3 API calls.

#### Step 1 — Start Session (RPC)
```
POST /rest/v1/rpc/start_tool_session
Body: { tool_id: uuid, palm1_id: uuid, palm2_id?: uuid }
```

**Internal flow of `start_tool_session()`:**
```
1. SELECT tool WHERE id = tool_id AND is_active = true  → 404 if not found
2. SELECT palm WHERE id = palm1_id AND owner_id = auth.uid()  → 403 if not owned
3. (if palm2_id) SELECT palm WHERE id = palm2_id AND owner_id = auth.uid()
4. internal_deduct_credits(auth.uid(), tool.credit_cost, 'tool_usage', ...)
   → checks credit_balance >= credit_cost; raises exception if insufficient
   → UPDATE profiles SET credit_balance -= credit_cost
   → INSERT credit_transactions (amount negative, type='tool_usage')
5. INSERT tool_sessions (status='pending', credits_used=credit_cost)
6. RETURN session_id
```

Returns: `uuid` (session_id)

#### Step 2 — Run AI Analysis (Edge Function)
```
POST /functions/v1/analyze-palm
Body: { session_id: uuid }
```
See [Section 5.1](#51-analyze-palm-edge-function) for full execution flow.

#### Step 3 — Fetch Results
```
GET /rest/v1/tool_sessions?id=eq.<session_id>&select=*,tool_session_metrics(*),session_solutions(*)
```
RLS ensures only session owner can read.

---

### 4.5 Solution Unlock (RPC)
```
POST /rest/v1/rpc/unlock_solution
Body: { session_id: uuid, solution_type: "traditional" | "science_backed" }
```

**Internal flow of `unlock_solution()`:**
```
1. SELECT session_solutions WHERE session_id = ? AND type = solution_type
   → via tool_sessions JOIN for ownership check
   → error if already unlocked
2. internal_deduct_credits(auth.uid(), 5, 'solution_unlock', ...)
3. UPDATE session_solutions SET is_unlocked=true, unlocked_at=now()
4. RETURN { id, content, is_unlocked, unlocked_at }
```

---

### 4.6 Chat Workflow

#### Create Chat Session
```
POST /rest/v1/chat_sessions
Body: { user_id, title?, tool_session_id? }
```

#### Send Message (Edge Function)
```
POST /functions/v1/chat
Body: { chat_session_id: uuid, message: string (max 2000 chars) }
```
See [Section 5.2](#52-chat-edge-function) for full execution flow.

#### Get Messages
```
GET /rest/v1/chat_messages?chat_session_id=eq.<id>&order=created_at.asc
```

---

### 4.7 Credits & Rewards (RPC)

#### Get Credit Balance + History
```
POST /rest/v1/rpc/get_my_credits
```
Returns: `{ balance: int, recent_transactions: [{ id, amount, type, description, balance_after, created_at }] }`
Last 20 transactions ordered by `created_at DESC`.

#### Record Share Reward
```
POST /rest/v1/rpc/record_share_reward
Body: { tool_id: uuid }
```
Rate-limited: once per tool per 24 hours. Grants 2 credits if eligible.

---

### 4.8 Review (RPC)
```
POST /rest/v1/rpc/submit_review
Body: { tool_id: uuid, rating: 1-5, review_text?: string, session_id?: uuid }
```
**Internal flow:**
```
1. INSERT INTO tool_reviews (upsert: one review per user per tool)
2. BEFORE INSERT trigger fn_grant_review_credits() fires:
   → If new review: internal_grant_credits(auth.uid(), 3, 'review_reward', ...)
3. RETURN { id, rating, credits_earned, is_new_review }
```

---

### 4.9 Action Plan Progression (RPC)
```
POST /rest/v1/rpc/advance_action
Body: { progress_id: uuid, feeling: reflection_feeling, notes?: string }
```
**Internal flow:**
```
1. UPDATE user_action_progress SET status='completed', feeling=?, notes=?
2. Find next action in sequence (order_index + 1) for same session
3. UPDATE next action SET status='available'
4. RETURN { completed: uuid, next: uuid, has_next: bool }
```

---

### 4.10 Payments (Edge Function / Webhook)
```
POST /functions/v1/process-payment
Headers: stripe-signature OR X-RevenueCat-Signature
Body: raw webhook payload
```
See [Section 5.3](#53-process-payment-edge-function) for full execution flow.

---

### 4.11 Notifications (RPC + REST)

#### List Notifications
```
GET /rest/v1/notifications?user_id=eq.<uid>&order=created_at.desc
```

#### Mark All Read (RPC)
```
POST /rest/v1/rpc/mark_all_notifications_read
```
Updates all `is_read = false` → `true` for `auth.uid()`. Returns count updated.

---

### 4.12 Catalogue Endpoints (Read-only)

All lookup data is SELECT-only via RLS for `authenticated` role.

| Endpoint | Data |
|---|---|
| `GET /rest/v1/categories` | 6 life categories |
| `GET /rest/v1/languages` | 8 languages |
| `GET /rest/v1/tools?is_active=eq.true` | All active tools |
| `GET /rest/v1/tools?is_featured=eq.true` | Featured tools |
| `GET /rest/v1/tool_features?tool_id=eq.<id>` | Tool feature bullets |
| `GET /rest/v1/subscription_plans?is_active=eq.true` | Credit packs |
| `GET /rest/v1/banners?is_active=eq.true&order=display_order.asc` | Active banners |

---

## 5. Backend Function Execution Flow

### 5.1 `analyze-palm` Edge Function

**Trigger:** `POST /functions/v1/analyze-palm`
**Runtime:** Deno
**AI Model:** Claude Opus 4.6

```mermaid
flowchart TD
    A[POST /functions/v1/analyze-palm] --> B{OPTIONS?}
    B -->|Yes| C[Return 204 CORS]
    B -->|No| D[Extract JWT → getUser]
    D --> E{Valid user?}
    E -->|No| F[401 Unauthorized]
    E -->|Yes| G[SELECT tool_sessions + palms<br/>WHERE id=session_id AND user_id=auth.uid]
    G --> H{Session found?}
    H -->|No| I[404 Not Found]
    H -->|Yes| J{Status = pending or processing?}
    J -->|No| K[400 Invalid status]
    J -->|Yes| L[UPDATE status = 'processing']
    L --> M[Fetch palm images from Storage as base64]
    M --> N{All images valid?}
    N -->|No| O[Mark failed → 500]
    N -->|Yes| P[Build Claude prompt<br/>system + image content blocks]
    P --> Q[POST to Anthropic API<br/>claude-opus-4-6]
    Q --> R{Response valid JSON?}
    R -->|No| O
    R -->|Yes| S[BEGIN atomic write]
    S --> T[UPDATE tool_sessions<br/>status=completed, overall_score, summary_text, result_data]
    T --> U[INSERT 6 × tool_session_metrics<br/>one per life category]
    U --> V[INSERT 2 × session_solutions<br/>traditional + science_backed, is_unlocked=false]
    V --> W[COMMIT]
    W --> X[200 OK: session_id]
    O --> Y[UPDATE status = 'failed']
    Y --> Z[fn_refund_on_failure trigger fires → refund credits]
```

**Claude System Prompt Instructions (structured output):**
```
Return a JSON object with these exact fields:
{
  "overall_score": number (0-100),
  "summary_text": string (2-3 sentences),
  "metrics": [
    { "category": "Relationship|Finance|Career|Health|Growth|Personal Life",
      "score": number, "interpretation": string }
  ],
  "key_lines": { "heart": string, "head": string, "life": string, "fate": string },
  "mounts": { "venus": string, "jupiter": string, "saturn": string, "apollo": string, "mercury": string },
  "detailed_analysis": string,
  "traditional_advice": string,
  "science_backed_advice": string
}
```

**Error Handling:**
- Image fetch failure → session marked `failed`, credits refunded automatically via trigger
- Claude non-JSON response → session marked `failed`, credits refunded
- DB write failure → session marked `failed`, credits refunded

---

### 5.2 `chat` Edge Function

**Trigger:** `POST /functions/v1/chat`
**Runtime:** Deno
**AI Model:** Claude Haiku 4.5

```mermaid
flowchart TD
    A[POST /functions/v1/chat] --> B[Validate JWT + user]
    B --> C[SELECT chat_sessions<br/>WHERE id=chat_session_id AND user_id=auth.uid]
    C --> D{Session owned?}
    D -->|No| E[403 Forbidden]
    D -->|Yes| F[Validate message length ≤ 2000 chars]
    F --> G[SELECT last 20 chat_messages<br/>ORDER BY created_at DESC]
    G --> H{Session has tool_session_id?}
    H -->|Yes| I[SELECT tool_sessions<br/>fetch summary, score, detailed_analysis]
    H -->|No| J[Base system prompt only]
    I --> K[Build enriched system prompt<br/>with reading context]
    K --> L[INSERT user message<br/>chat_messages role=user]
    J --> L
    L --> M[POST to Anthropic API<br/>claude-haiku-4-5 with message history]
    M --> N{API success?}
    N -->|No| O[DELETE pre-saved user message<br/>500 error response]
    N -->|Yes| P[INSERT assistant reply<br/>chat_messages role=assistant]
    P --> Q[UPDATE chat_sessions.updated_at]
    Q --> R[200 OK: message_id, content, created_at]
```

**System Prompt Structure:**
- Base: warm, empathetic palm reading assistant personality
- Context injection (if tool session linked and completed):
  - User's overall score
  - Session summary
  - Detailed analysis text

**Message History:** Last 20 messages sent to Claude as `messages[]` array (`user`/`assistant` roles).

---

### 5.3 `process-payment` Edge Function

**Trigger:** Webhook POST from Stripe or RevenueCat
**Runtime:** Deno

```mermaid
flowchart TD
    A[POST /functions/v1/process-payment] --> B[Read raw body as text]
    B --> C{Provider detection}
    C -->|stripe-signature header| D[Stripe HMAC-SHA256 verify]
    C -->|X-RevenueCat-Signature header| E[RevenueCat HMAC-SHA256-base64 verify]
    D --> F{Signature valid?}
    E --> F
    F -->|No| G[401 Unauthorized]
    F -->|Yes| H[Parse JSON body]
    H --> I[Normalize event:<br/>provider, externalRef, userId, planSlug, amountUsd, status]
    I --> J{userId in payload?}
    J -->|No| K[Lookup profiles by billing_email]
    J -->|Yes| L[Use userId directly]
    K --> L
    L --> M[SELECT subscription_plans<br/>WHERE slug = planSlug]
    M --> N{Plan found?}
    N -->|No| O[404 Unknown plan]
    N -->|Yes| P[SELECT user_purchases<br/>WHERE payment_provider_ref = externalRef]
    P --> Q{Existing purchase?}
    Q -->|Same status| R[200 duplicate_event]
    Q -->|Different status| S[UPDATE payment_status only]
    Q -->|New| T[INSERT user_purchases<br/>credits_granted = plan.credits_included]
    T --> U{payment_status = 'completed'?}
    U -->|Yes| V[fn_grant_credits_on_purchase trigger fires:<br/>grant credits + send notification]
    U -->|No| W[No credit action]
    S --> X[200 status_updated]
    V --> X
    W --> X
```

**Event Normalization (Stripe):**
- `checkout.session.completed` → status: `completed`
- `payment_intent.payment_failed` → status: `failed`
- `charge.refunded` → status: `refunded`

**Event Normalization (RevenueCat):**
- `INITIAL_PURCHASE`, `RENEWAL` → status: `completed`
- `BILLING_ISSUE` → status: `failed`
- `CANCELLATION` → status: `refunded`

---

### 5.4 RPC Functions Summary

| Function | Cost | Credits | Key Logic |
|---|---|---|---|
| `start_tool_session` | Deducts tool cost | -N | Validates tool + palm + balance; creates session |
| `unlock_solution` | -5 credits | -5 | Validates ownership + completion; sets is_unlocked |
| `submit_review` | None | +3 | Upsert review; trigger grants credits on first review |
| `advance_action` | None | 0 | Marks step done; unlocks next sequential step |
| `record_share_reward` | None | +2 | Rate-limited; 1 reward per tool per 24h |
| `get_my_credits` | None | Read-only | Balance + last 20 transactions |
| `validate_promo_code` | None | Read-only | Code validity + discount info |
| `mark_all_notifications_read` | None | 0 | Bulk update unread → read |

---

## 6. Database Workflow

### 6.1 Table Relationships

```mermaid
erDiagram
    auth_users ||--|| profiles : "1:1 (trigger)"
    profiles ||--o{ palms : "owns"
    profiles ||--o{ tool_sessions : "runs"
    profiles ||--o{ chat_sessions : "has"
    profiles ||--o{ credit_transactions : "ledger"
    profiles ||--o{ user_purchases : "buys"
    profiles ||--o{ notifications : "receives"

    palms }o--o{ tool_sessions : "analysed in"
    tools ||--o{ tool_sessions : "type"
    tools ||--o{ tool_features : "has features"
    categories ||--o{ tools : "groups"
    tool_creators ||--o{ tools : "created by"

    tool_sessions ||--o{ tool_session_metrics : "6 scores"
    tool_sessions ||--o{ session_solutions : "2 solutions"
    tool_sessions ||--o{ user_action_progress : "action steps"
    tool_sessions ||--o| tool_reviews : "reviewed"

    chat_sessions ||--o{ chat_messages : "contains"
    chat_sessions }o--o| tool_sessions : "optionally linked"

    actionable_plans ||--o{ plan_actions : "steps"
    plan_actions ||--o{ action_steps : "instructions"
    plan_actions ||--o{ user_action_progress : "tracks"

    subscription_plans ||--o{ user_purchases : "fulfilled by"
    promo_codes }o--o{ user_purchases : "applied to"
    languages }o--o{ profiles : "preferred"
```

### 6.2 Credit Ledger Flow

Credits are stored in two places: the **running balance** (`profiles.credit_balance`) and an **immutable ledger** (`credit_transactions`). Both are updated atomically by `internal_deduct_credits()` and `internal_grant_credits()`.

```mermaid
flowchart LR
    A[User Action] --> B{Earn or Spend?}
    B -->|Earn| C[internal_grant_credits]
    B -->|Spend| D[internal_deduct_credits]
    C --> E[UPDATE profiles<br/>credit_balance += amount]
    D --> F[CHECK credit_balance >= amount<br/>RAISE if insufficient]
    F --> G[UPDATE profiles<br/>credit_balance -= amount]
    E --> H[INSERT credit_transactions<br/>amount positive, balance_after]
    G --> I[INSERT credit_transactions<br/>amount negative, balance_after]
```

**Credit Sources:**

| Event | Amount | Type |
|---|---|---|
| Sign up | +5 | `signup_bonus` |
| Referral bonus (referrer) | +10 | `referral_bonus` |
| Submit review (new only) | +3 | `review_reward` |
| Share tool | +2 | `share_reward` |
| Purchase credit pack | +N | `purchase` |
| Admin grant | +N | `admin_grant` |
| Promo code | +N | `promo_bonus` |
| Use a tool | -N | `tool_usage` |
| Unlock solution | -5 | `solution_unlock` |
| Refund on failure | +N | `tool_refund` |

### 6.3 RLS Policies Summary

```mermaid
flowchart TD
    REQ[Incoming SQL Query] --> RLS{RLS Check}

    RLS -->|User tables<br/>profiles, palms, sessions| OWN[auth.uid = user_id<br/>→ own data only]
    RLS -->|Lookup tables<br/>categories, languages, tools| PUB[SELECT only<br/>authenticated role]
    RLS -->|System writes<br/>credit_transactions, notifications| SVC[service_role only<br/>no direct user write]
    RLS -->|Public data<br/>banners, tool_features| ALL[anon + authenticated<br/>SELECT only]

    OWN --> PASS[Query Executes]
    PUB --> PASS
    SVC --> PASS
    ALL --> PASS
```

---

## 7. Background Processes and Triggers

All triggers are PostgreSQL trigger functions (`SECURITY DEFINER`) that fire automatically on table changes.

### 7.1 Trigger Map

```mermaid
flowchart TD
    subgraph auth.users
        AU_INSERT[INSERT on auth.users]
    end

    subgraph tool_sessions
        TS_UPDATE[UPDATE status]
    end

    subgraph user_purchases
        UP_INSERT[INSERT]
        UP_UPDATE[UPDATE payment_status]
    end

    subgraph tool_reviews
        TR_INSERT[BEFORE INSERT]
    end

    AU_INSERT -->|AFTER INSERT| T1[handle_new_user<br/>→ create profile + 5 credits<br/>→ referral bonus if applicable]

    TS_UPDATE -->|AFTER UPDATE<br/>status = completed| T2[fn_init_action_progress<br/>→ insert user_action_progress rows<br/>→ unlock first action]

    TS_UPDATE -->|AFTER UPDATE<br/>status = completed/failed| T3[fn_notify_session_status<br/>→ insert notification]

    TS_UPDATE -->|AFTER UPDATE<br/>status = failed| T4[fn_refund_on_failure<br/>→ internal_grant_credits<br/>→ refund credits_used]

    UP_INSERT -->|AFTER INSERT<br/>has promo_code_id| T5[fn_increment_promo_usage<br/>→ promo_codes.used_count++]

    UP_INSERT -->|AFTER INSERT<br/>payment_status = completed| T6[fn_grant_credits_on_purchase<br/>→ internal_grant_credits<br/>→ insert notification]

    UP_UPDATE -->|AFTER UPDATE<br/>payment_status → completed| T6

    TR_INSERT -->|BEFORE INSERT<br/>new review only| T7[fn_grant_review_credits<br/>→ internal_grant_credits 3 credits]
```

### 7.2 `handle_new_user()` — Signup Trigger

```sql
-- Fires: AFTER INSERT ON auth.users
1. Extract referred_by from raw_user_meta_data->>'referred_by'
2. INSERT INTO profiles (id=new.id, credit_balance=5)
3. INSERT INTO credit_transactions (type='signup_bonus', amount=5)
4. IF referred_by IS NOT NULL AND referred_by != new.id:
   a. internal_grant_credits(referred_by, 10, 'referral_bonus', ...)
   b. INSERT INTO notifications (user_id=referred_by, message='You earned 10 credits!')
```

### 7.3 `fn_init_action_progress()` — Action Plan Initialization

```sql
-- Fires: AFTER UPDATE ON tool_sessions WHERE status = 'completed'
1. Find actionable_plan linked to tool (tools.actionable_plan_id)
2. SELECT all plan_actions WHERE plan_id = ? ORDER BY order_index
3. FOR EACH action:
   INSERT INTO user_action_progress (user_id, session_id, plan_action_id, status)
   status = 'available' if order_index = 1 ELSE 'locked'
```

### 7.4 `fn_refund_on_failure()` — Credit Refund

```sql
-- Fires: AFTER UPDATE ON tool_sessions WHERE NEW.status = 'failed'
IF OLD.status != 'failed':
  internal_grant_credits(
    user_id = session.user_id,
    amount = session.credits_used,
    type = 'tool_refund',
    description = 'Refund for failed analysis',
    ref_id = session.id,
    ref_type = 'tool_sessions'
  )
```

### 7.5 `set_updated_at()` — Timestamp Maintenance

Applied to 15+ tables. Fires BEFORE UPDATE, sets `updated_at = now()` automatically.

---

## 8. External Service Integration

### 8.1 Anthropic Claude — Palm Analysis

```mermaid
sequenceDiagram
    participant EF as analyze-palm Edge Function
    participant ST as Supabase Storage
    participant ANT as Anthropic API

    EF->>ST: GET /storage/v1/object/<palm-image-path>
    ST-->>EF: Binary image data
    EF->>EF: base64 encode image
    EF->>ANT: POST /v1/messages<br/>model: claude-opus-4-6<br/>max_tokens: 4096<br/>system: palm reading instructions<br/>messages: [{role: user, content: [image_block, text_block]}]
    ANT-->>EF: { content: [{ type: text, text: "{...json...}" }] }
    EF->>EF: JSON.parse(response.content[0].text)
    EF->>DB: Write structured results
```

**API Call Parameters:**
```json
{
  "model": "claude-opus-4-6",
  "max_tokens": 4096,
  "system": "<palm reading system prompt>",
  "messages": [{
    "role": "user",
    "content": [
      { "type": "image", "source": { "type": "base64", "media_type": "image/jpeg", "data": "..." } },
      { "type": "text", "text": "Analyse this palm. Return JSON only." }
    ]
  }]
}
```

### 8.2 Anthropic Claude — Chat

```json
{
  "model": "claude-haiku-4-5-20251001",
  "max_tokens": 1024,
  "system": "<context-aware assistant prompt>",
  "messages": [
    { "role": "user", "content": "..." },
    { "role": "assistant", "content": "..." },
    ...
    { "role": "user", "content": "<new message>" }
  ]
}
```

### 8.3 Stripe — Payment Webhook

```mermaid
sequenceDiagram
    participant ST as Stripe
    participant EF as process-payment
    participant DB as PostgreSQL

    ST->>EF: POST /functions/v1/process-payment<br/>stripe-signature: t=...,v1=...
    EF->>EF: HMAC-SHA256 verify<br/>timestamp + raw body + STRIPE_WEBHOOK_SECRET
    EF->>EF: Normalize event to standard schema
    EF->>DB: SELECT subscription_plans WHERE slug = planSlug
    EF->>DB: SELECT user_purchases WHERE provider_ref = externalRef
    EF->>DB: INSERT user_purchases OR UPDATE payment_status
    DB--)DB: fn_grant_credits_on_purchase trigger<br/>(if status=completed)
    EF-->>ST: { received: true, processed: true }
```

**Signature Verification (Stripe):**
```
signedPayload = timestamp + "." + rawBody
expectedSig = HMAC-SHA256(STRIPE_WEBHOOK_SECRET, signedPayload)
compare with v1=<signature> from header
```

### 8.4 RevenueCat — Payment Webhook

```
signature = HMAC-SHA256-base64(REVENUECAT_WEBHOOK_SECRET, rawBody)
compare with X-RevenueCat-Signature header
```

---

## 9. Error Handling and Recovery Logic

### 9.1 Edge Function Error Strategy

```mermaid
flowchart TD
    A[Edge Function invoked] --> B{handleCors?}
    B -->|OPTIONS| C[204 immediately]
    B -->|POST| D[Try main logic]

    D --> E{Error type?}
    E -->|Auth failure| F[401 Unauthorized<br/>errorResponse]
    E -->|Not found| G[404 Not Found<br/>errorResponse]
    E -->|Validation| H[400 Bad Request<br/>errorResponse]
    E -->|AI API error| I{Which function?}
    E -->|DB error| J[500 + log<br/>errorResponse]

    I -->|analyze-palm| K[UPDATE session status=failed<br/>→ trigger auto-refunds credits<br/>500 response]
    I -->|chat| L[DELETE pre-saved user message<br/>500 response]
```

### 9.2 RPC Function Error Strategy

All RPC functions use `RAISE EXCEPTION` for error cases:
- PostgREST converts these to `HTTP 400` with `{ error: <message> }`.
- Transaction is fully rolled back on any exception.

| Error Condition | Exception Message | HTTP Code |
|---|---|---|
| Tool not found or inactive | `tool_not_found` | 400 |
| Palm not owned by user | `palm_not_found` | 400 |
| Insufficient credits | `insufficient_credits` | 400 |
| Session not completed | `session_not_completed` | 400 |
| Solution already unlocked | `already_unlocked` | 400 |
| Invalid promo code | `invalid_or_expired` | 400 (in JSON) |
| Rate limit exceeded (share) | `already_rewarded_today` | 200 (rewarded=false) |

### 9.3 Credit Refund on Failure

```mermaid
sequenceDiagram
    participant EF as Edge Function
    participant DB as PostgreSQL
    participant TR as fn_refund_on_failure trigger

    EF->>DB: UPDATE tool_sessions SET status='failed'
    DB--)TR: AFTER UPDATE trigger fires
    TR->>DB: internal_grant_credits(user_id, credits_used, 'tool_refund')
    DB->>DB: UPDATE profiles SET credit_balance += credits_used
    DB->>DB: INSERT credit_transactions (positive amount)
    DB->>DB: INSERT notifications (refund message)
```

### 9.4 Payment Idempotency

```mermaid
flowchart TD
    A[Webhook received] --> B[Verify signature]
    B --> C[SELECT user_purchases WHERE provider_ref = externalRef]
    C --> D{Exists?}
    D -->|No| E[INSERT new purchase]
    D -->|Same status| F[Return duplicate_event<br/>no DB change]
    D -->|Different status| G[UPDATE payment_status only<br/>no duplicate credit grant]
```

---

## 10. Data Flow Through the System

### 10.1 Complete Palm Analysis Flow

```mermaid
sequenceDiagram
    participant U as User (App)
    participant API as Supabase REST API
    participant ST as Storage
    participant RPC as PostgreSQL RPC
    participant EF as analyze-palm Edge Fn
    participant AI as Claude Opus 4.6
    participant TR as DB Triggers

    U->>ST: Upload palm image
    ST-->>U: image_url

    U->>API: POST /rest/v1/palms { image_url, ... }
    API-->>U: palm_id

    U->>RPC: POST /rpc/start_tool_session { tool_id, palm_id }
    RPC->>RPC: Validate + deduct credits
    RPC-->>U: session_id

    U->>EF: POST /functions/v1/analyze-palm { session_id }
    EF->>API: UPDATE session status=processing
    EF->>ST: Fetch palm image as base64
    EF->>AI: Send images + system prompt
    AI-->>EF: JSON analysis
    EF->>API: UPDATE session + INSERT metrics + INSERT solutions
    API--)TR: fn_init_action_progress fires
    TR->>API: INSERT user_action_progress rows
    API--)TR: fn_notify_session_status fires
    TR->>API: INSERT notification
    EF-->>U: { session_id } 200 OK

    U->>API: GET /rest/v1/tool_sessions?select=*,metrics(*),solutions(*)
    API-->>U: Full session with scores
```

### 10.2 Chat with Context Flow

```mermaid
sequenceDiagram
    participant U as User
    participant API as REST API
    participant EF as chat Edge Fn
    participant AI as Claude Haiku 4.5

    U->>API: POST /rest/v1/chat_sessions { tool_session_id }
    API-->>U: chat_session_id

    loop Each Message
        U->>EF: POST /functions/v1/chat { chat_session_id, message }
        EF->>API: SELECT chat_messages (last 20)
        EF->>API: SELECT tool_sessions (summary + analysis)
        EF->>API: INSERT chat_messages role=user
        EF->>AI: messages[] with context-aware system prompt
        AI-->>EF: assistant reply
        EF->>API: INSERT chat_messages role=assistant
        EF-->>U: { message_id, content }
    end
```

### 10.3 Credit Lifecycle Flow

```mermaid
flowchart LR
    SIGNUP[Signup<br/>+5 credits] --> BAL[(credit_balance)]
    REFERRAL[Referred someone<br/>+10 credits] --> BAL
    REVIEW[Submit review<br/>+3 credits] --> BAL
    SHARE[Share tool<br/>+2 credits] --> BAL
    PURCHASE[Buy credit pack<br/>+N credits] --> BAL

    BAL --> TOOL[Use tool<br/>-N credits]
    BAL --> UNLOCK[Unlock solution<br/>-5 credits]

    TOOL -->|on failure| REFUND[Auto-refund<br/>+N credits] --> BAL

    BAL --> TXN[(credit_transactions<br/>immutable ledger)]
```

### 10.4 Payment-to-Credits Flow

```mermaid
sequenceDiagram
    participant PM as Payment Provider
    participant EF as process-payment
    participant DB as PostgreSQL
    participant TR as fn_grant_credits_on_purchase

    PM->>EF: Webhook (signed)
    EF->>EF: Verify HMAC signature
    EF->>EF: Normalize event
    EF->>DB: Idempotency check
    EF->>DB: INSERT user_purchases { payment_status=completed, credits_granted=N }
    DB--)TR: AFTER INSERT trigger
    TR->>DB: internal_grant_credits(user_id, N, 'purchase')
    DB->>DB: UPDATE profiles.credit_balance += N
    DB->>DB: INSERT credit_transactions
    DB->>DB: INSERT notifications (credits added message)
    EF-->>PM: 200 { received: true, processed: true }
```

---

## Appendix: Environment Variables

| Variable | Used In | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | analyze-palm, chat | Authenticate with Anthropic API |
| `SUPABASE_URL` | All edge functions | Supabase project endpoint |
| `SUPABASE_ANON_KEY` | Client calls | Public API access |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge functions | Bypass RLS for internal writes |
| `STRIPE_WEBHOOK_SECRET` | process-payment | Stripe signature verification |
| `REVENUECAT_WEBHOOK_SECRET` | process-payment | RevenueCat signature verification |

## Appendix: Key File Index

| File | Purpose |
|---|---|
| [supabase/migrations/20260306200001_palmyst_schema.sql](supabase/migrations/20260306200001_palmyst_schema.sql) | Core schema — 23 tables, ENUMs, RLS, indexes |
| [supabase/migrations/20260310000001_backend_logic.sql](supabase/migrations/20260310000001_backend_logic.sql) | Business logic — 8 RPC functions, 6 triggers |
| [supabase/functions/analyze-palm/index.ts](supabase/functions/analyze-palm/index.ts) | AI palm reading edge function |
| [supabase/functions/chat/index.ts](supabase/functions/chat/index.ts) | Conversational AI edge function |
| [supabase/functions/process-payment/index.ts](supabase/functions/process-payment/index.ts) | Payment webhook handler |
| [supabase/functions/_shared/cors.ts](supabase/functions/_shared/cors.ts) | CORS headers + OPTIONS handler |
| [supabase/functions/_shared/errors.ts](supabase/functions/_shared/errors.ts) | Error/JSON response helpers |
| [doc/db-schema.md](doc/db-schema.md) | Full ER diagram + table definitions |
| [API.md](API.md) | REST API reference (54+ endpoints) |
