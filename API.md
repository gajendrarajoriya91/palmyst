# Palmyst REST API Reference

> Backend: Supabase (PostgreSQL 17) | Auth: Supabase JWT | AI: Anthropic Claude

---

## Base URLs

| Environment | Base URL |
|---|---|
| Local | `http://127.0.0.1:54321` |
| Production | `https://<project-ref>.supabase.co` |

## API Layers

| Layer | Path Prefix | Purpose |
|---|---|---|
| Supabase Auth | `/auth/v1/` | Registration, login, token management |
| REST (PostgREST) | `/rest/v1/` | Table CRUD + RPC functions |
| Edge Functions | `/functions/v1/` | AI analysis, chat, payment webhooks |
| Storage | `/storage/v1/` | Palm image upload and retrieval |

## Standard Headers

Every request requires:

```
apikey: <supabase-anon-key>
```

Every authenticated request additionally requires:

```
Authorization: Bearer <jwt-access-token>
Content-Type: application/json
```

Mutations that should return the created/updated row:

```
Prefer: return=representation
```

## Response Format

All REST endpoints return JSON arrays. To receive a single object, add:

```
Accept: application/vnd.pgrst.object+json
```

## HTTP Status Codes

| Code | Meaning |
|---|---|
| 200 | Success (RPC, GET) |
| 201 | Created (POST insert with Prefer: return=representation) |
| 204 | No content (DELETE, PATCH without Prefer header) |
| 400 | Bad request / validation error |
| 401 | Missing or invalid JWT |
| 403 | RLS denied access |
| 404 | Row not found |
| 409 | Conflict (unique constraint) |
| 422 | Unprocessable entity |

## RPC Error Format

Business logic errors from RPC functions are returned as:

```json
{
  "code": "PGRST116",
  "details": null,
  "hint": null,
  "message": "insufficient_credits"
}
```

Common RPC error messages: `not_authenticated`, `tool_not_found`, `invalid_palm`, `second_palm_required`, `insufficient_credits`, `session_not_found`, `solution_not_found`, `invalid_rating`, `progress_not_found`, `action_locked`, `already_completed`.

---

## 1. Authentication `/auth/v1/`

### Sign Up

```
POST /auth/v1/signup
```

Headers: `apikey`

Request:
```json
{
  "email": "user@example.com",
  "password": "Password123!",
  "data": {
    "full_name": "Jane Doe",
    "referred_by": "uuid-of-referrer-profile"
  }
}
```

Response `200`:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "...",
  "expires_in": 3600,
  "token_type": "bearer",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "created_at": "2026-03-10T12:00:00Z"
  }
}
```

Notes: `referred_by` is optional. Triggers `handle_new_user()` which creates the profile with 5 welcome credits and credits the referrer 10 credits.

---

### Sign In

```
POST /auth/v1/token?grant_type=password
```

Headers: `apikey`

Request:
```json
{
  "email": "user@example.com",
  "password": "Password123!"
}
```

Response `200`: Same shape as Sign Up response.

---

### Refresh Token

```
POST /auth/v1/token?grant_type=refresh_token
```

Headers: `apikey`

Request:
```json
{
  "refresh_token": "..."
}
```

Response `200`: New `access_token` and `refresh_token`.

---

### Get Current User

```
GET /auth/v1/user
```

Headers: `apikey`, `Authorization`

Response `200`:
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "user_metadata": { "full_name": "Jane Doe", "avatar_url": "..." },
  "created_at": "..."
}
```

---

### Update User

```
PUT /auth/v1/user
```

Headers: `apikey`, `Authorization`

Request (update password):
```json
{
  "password": "NewPassword456!"
}
```

Request (update metadata):
```json
{
  "data": { "full_name": "Jane Smith" }
}
```

Response `200`: Updated user object.

---

### Sign Out

```
POST /auth/v1/logout
```

Headers: `apikey`, `Authorization`

Response `204`: No content.

---

### Request Password Reset

```
POST /auth/v1/recover
```

Headers: `apikey`

Request:
```json
{
  "email": "user@example.com"
}
```

Response `200`: Empty object.

---

## 2. Profiles `/rest/v1/profiles`

### Get My Profile

```
GET /rest/v1/profiles?select=*
```

Headers: `apikey`, `Authorization`

RLS returns only the caller's row.

Response `200`:
```json
[
  {
    "id": "uuid",
    "display_name": "Jane Doe",
    "avatar_url": "https://...",
    "preferred_language_id": "uuid",
    "credit_balance": 23,
    "referred_by": null,
    "created_at": "...",
    "updated_at": "..."
  }
]
```

---

### Update My Profile

```
PATCH /rest/v1/profiles?id=eq.<user_id>
```

Headers: `apikey`, `Authorization`, `Prefer: return=representation`

Request (partial update):
```json
{
  "display_name": "Jane Smith",
  "preferred_language_id": "uuid"
}
```

Response `200`: Updated profile array.

---

## 3. Palms `/rest/v1/palms`

### List My Palms

```
GET /rest/v1/palms?select=*&order=created_at.desc
```

Headers: `apikey`, `Authorization`

Response `200`:
```json
[
  {
    "id": "uuid",
    "owner_id": "uuid",
    "name": "My Palm",
    "age": 28,
    "gender": "female",
    "palm_image_url": "https://...",
    "is_self": true,
    "created_at": "...",
    "updated_at": "..."
  }
]
```

---

### Get Palm by ID

```
GET /rest/v1/palms?id=eq.<palm_id>&select=*
```

Headers: `apikey`, `Authorization`, `Accept: application/vnd.pgrst.object+json`

Response `200`: Single palm object.

---

### Create Palm

```
POST /rest/v1/palms
```

Headers: `apikey`, `Authorization`, `Prefer: return=representation`

Request:
```json
{
  "owner_id": "{{user_id}}",
  "name": "My Palm",
  "age": 28,
  "gender": "female",
  "is_self": true
}
```

Response `201`: Created palm array.

Note: `palm_image_url` is set separately after uploading the image to Storage.

---

### Update Palm

```
PATCH /rest/v1/palms?id=eq.<palm_id>
```

Headers: `apikey`, `Authorization`, `Prefer: return=representation`

Request:
```json
{
  "palm_image_url": "https://...",
  "age": 29
}
```

Response `200`: Updated palm array.

---

### Delete Palm

```
DELETE /rest/v1/palms?id=eq.<palm_id>
```

Headers: `apikey`, `Authorization`

Response `204`: No content.

---

## 4. Catalogue

### List Active Categories

```
GET /rest/v1/categories?order=display_order&select=*
```

Headers: `apikey`, `Authorization`

RLS restricts to `is_active = true` rows.

Response `200`:
```json
[
  {
    "id": "uuid",
    "name": "Relationship",
    "slug": "relationship",
    "icon_url": "https://...",
    "display_order": 1,
    "is_active": true
  }
]
```

---

### List Active Languages

```
GET /rest/v1/languages?order=display_order&select=*
```

Response `200`: Array of language objects with `id`, `name`, `code`, `is_active`.

---

### List Tool Creators

```
GET /rest/v1/tool_creators?select=*
```

Response `200`: Array of creator objects.

---

## 5. Tools `/rest/v1/tools`

### List All Active Tools

```
GET /rest/v1/tools?select=*,categories(name,slug)&order=display_order
```

Headers: `apikey`, `Authorization`

Response `200`:
```json
[
  {
    "id": "uuid",
    "name": "Love & Compatibility",
    "slug": "love-compatibility",
    "description": "...",
    "short_description": "...",
    "icon_url": "https://...",
    "credit_cost": 10,
    "min_palms_required": 2,
    "is_featured": true,
    "is_active": true,
    "display_order": 1,
    "categories": { "name": "Relationship", "slug": "relationship" }
  }
]
```

---

### List Featured Tools

```
GET /rest/v1/tools?is_featured=eq.true&order=display_order&select=*
```

---

### Get Tool by ID (with features and creator)

```
GET /rest/v1/tools?id=eq.<tool_id>&select=*,tool_features(*),tool_creators(name,avatar_url,bio)
```

Headers: `apikey`, `Authorization`, `Accept: application/vnd.pgrst.object+json`

---

### Filter Tools by Category

```
GET /rest/v1/tools?category_id=eq.<category_id>&order=display_order&select=*
```

---

### Get Tool Features

```
GET /rest/v1/tool_features?tool_id=eq.<tool_id>&order=display_order&select=*
```

---

## 6. Tool Sessions `/rest/v1/tool_sessions`

### Start Tool Session (RPC)

```
POST /rest/v1/rpc/start_tool_session
```

Headers: `apikey`, `Authorization`

Request:
```json
{
  "p_tool_id": "uuid",
  "p_palm1_id": "uuid",
  "p_palm2_id": null
}
```

Response `200`: Session UUID string.

```json
"3f7a1b2c-..."
```

After receiving the session ID, immediately call `POST /functions/v1/analyze-palm`.

Errors: `tool_not_found`, `invalid_palm`, `second_palm_required`, `insufficient_credits`.

---

### List My Sessions

```
GET /rest/v1/tool_sessions?select=*,tools(name,icon_url)&order=created_at.desc
```

Headers: `apikey`, `Authorization`

---

### Get Session Detail (with metrics and solutions)

```
GET /rest/v1/tool_sessions?id=eq.<session_id>&select=*,tool_session_metrics(*),session_solutions(id,solution_type,is_unlocked,credits_to_unlock,unlocked_at)
```

Headers: `apikey`, `Authorization`, `Accept: application/vnd.pgrst.object+json`

Response `200`:
```json
{
  "id": "uuid",
  "tool_id": "uuid",
  "status": "completed",
  "overall_score": 78,
  "summary_text": "Your palm reveals...",
  "result_data": { "key_lines": {...}, "mounts": {...}, "detailed_analysis": "..." },
  "credits_used": 10,
  "created_at": "...",
  "tool_session_metrics": [
    { "metric_name": "Relationship", "score": 82, "unit": "%", "display_order": 1 }
  ],
  "session_solutions": [
    { "id": "uuid", "solution_type": "traditional", "is_unlocked": false, "credits_to_unlock": 5 }
  ]
}
```

---

### Get Session Metrics

```
GET /rest/v1/tool_session_metrics?session_id=eq.<session_id>&order=display_order&select=*
```

---

### Get Session Solutions

```
GET /rest/v1/session_solutions?session_id=eq.<session_id>&select=*
```

Note: `content` is returned for locked solutions too (the UI should hide it; enforcement is on the client). Alternatively, filter in query: `&is_unlocked=eq.true` to get only unlocked solutions.

---

## 7. Solutions

### Unlock Solution (RPC)

```
POST /rest/v1/rpc/unlock_solution
```

Headers: `apikey`, `Authorization`

Request:
```json
{
  "p_session_id": "uuid",
  "p_solution_type": "traditional"
}
```

`p_solution_type` is either `"traditional"` or `"science_backed"`.

Response `200`:
```json
{
  "id": "uuid",
  "content": "According to ancient palmistry traditions...",
  "is_unlocked": true,
  "unlocked_at": "2026-03-10T12:00:00Z"
}
```

Errors: `session_not_found`, `solution_not_found`, `insufficient_credits`.

---

## 8. Action Plans `/rest/v1/actionable_plans`

### Get Actionable Plan for Tool

```
GET /rest/v1/actionable_plans?tool_id=eq.<tool_id>&select=*,plan_actions(*)
```

---

### Get Plan Actions with Steps

```
GET /rest/v1/plan_actions?plan_id=eq.<plan_id>&select=*,action_steps(*)&order=display_order
```

---

### Get My Action Progress for Session

```
GET /rest/v1/user_action_progress?session_id=eq.<session_id>&select=*,plan_actions(title,why_this_matters,what_you_can_do,display_order)&order=created_at
```

Response `200`:
```json
[
  {
    "id": "uuid",
    "user_id": "uuid",
    "session_id": "uuid",
    "action_id": "uuid",
    "status": "available",
    "reflection_feeling": null,
    "reflection_notes": null,
    "completed_at": null,
    "plan_actions": {
      "title": "Morning Reflection Practice",
      "why_this_matters": "...",
      "what_you_can_do": "...",
      "display_order": 1
    }
  }
]
```

---

### Advance Action (RPC)

```
POST /rest/v1/rpc/advance_action
```

Headers: `apikey`, `Authorization`

Request:
```json
{
  "p_progress_id": "uuid",
  "p_feeling": "felt_good",
  "p_notes": "This exercise helped me realise..."
}
```

`p_feeling` values: `"felt_good"`, `"was_uncomfortable"`, `"not_sure_yet"`. Both fields are optional.

Response `200`:
```json
{
  "completed": "uuid",
  "next": "uuid",
  "has_next": true
}
```

Errors: `progress_not_found`, `action_locked`, `already_completed`.

---

## 9. Chat

### List Chat Sessions

```
GET /rest/v1/chat_sessions?select=*&order=updated_at.desc
```

Headers: `apikey`, `Authorization`

---

### Create Chat Session

```
POST /rest/v1/chat_sessions
```

Headers: `apikey`, `Authorization`, `Prefer: return=representation`

Request:
```json
{
  "user_id": "{{user_id}}",
  "tool_id": "uuid",
  "tool_session_id": "uuid",
  "title": "My Reading Questions"
}
```

`tool_id` and `tool_session_id` are optional. When `tool_session_id` is provided, the AI assistant is aware of that session's results.

Response `201`: Created chat session array.

---

### Delete Chat Session

```
DELETE /rest/v1/chat_sessions?id=eq.<chat_session_id>
```

Headers: `apikey`, `Authorization`

Response `204`: No content.

---

### Get Chat Messages

```
GET /rest/v1/chat_messages?chat_session_id=eq.<chat_session_id>&order=created_at.asc&select=*
```

Headers: `apikey`, `Authorization`

Response `200`:
```json
[
  {
    "id": "uuid",
    "chat_session_id": "uuid",
    "role": "user",
    "content": "What does my heart line mean?",
    "is_liked": null,
    "created_at": "..."
  },
  {
    "id": "uuid",
    "role": "assistant",
    "content": "Your heart line indicates strong emotional capacity...",
    "is_liked": null,
    "created_at": "..."
  }
]
```

---

### Like / Dislike a Message

```
PATCH /rest/v1/chat_messages?id=eq.<message_id>
```

Headers: `apikey`, `Authorization`

Request:
```json
{ "is_liked": true }
```

`is_liked`: `true` = liked, `false` = disliked, `null` = no rating.

---

## 10. Credits

### Get My Credits (RPC)

```
POST /rest/v1/rpc/get_my_credits
```

Headers: `apikey`, `Authorization`

Request: `{}`

Response `200`:
```json
{
  "balance": 23,
  "recent_transactions": [
    {
      "id": "uuid",
      "amount": -10,
      "type": "tool_usage",
      "description": "Palm reading analysis",
      "balance_after": 23,
      "created_at": "..."
    }
  ]
}
```

---

### Record Share Reward (RPC)

```
POST /rest/v1/rpc/record_share_reward
```

Headers: `apikey`, `Authorization`

Request:
```json
{ "p_tool_id": "uuid" }
```

Response `200` (rewarded):
```json
{ "rewarded": true, "credits_earned": 2, "balance": 25 }
```

Response `200` (rate-limited):
```json
{ "rewarded": false, "reason": "already_rewarded_today" }
```

---

## 11. Reviews `/rest/v1/tool_reviews`

### List Reviews for Tool

```
GET /rest/v1/tool_reviews?tool_id=eq.<tool_id>&select=*,profiles(display_name,avatar_url)&order=created_at.desc
```

All authenticated users can read all reviews (RLS allows it).

---

### Submit Review (RPC)

```
POST /rest/v1/rpc/submit_review
```

Headers: `apikey`, `Authorization`

Request:
```json
{
  "p_tool_id": "uuid",
  "p_rating": 5,
  "p_review_text": "Incredibly accurate and insightful!",
  "p_session_id": "uuid"
}
```

`p_review_text` and `p_session_id` are optional.

Response `200`:
```json
{
  "id": "uuid",
  "rating": 5,
  "credits_earned": 3,
  "is_new_review": true
}
```

On first submission: 3 credits awarded. On subsequent updates: `credits_earned: 0`.

Errors: `invalid_rating`, `tool_not_found`.

---

## 12. Subscriptions & Purchases

### List Active Subscription Plans

```
GET /rest/v1/subscription_plans?order=display_order&select=*
```

Response `200`:
```json
[
  {
    "id": "uuid",
    "name": "Basic",
    "slug": "basic",
    "description": "...",
    "price_usd": 4.99,
    "credits_included": 50,
    "features": ["Unlimited readings", "..."],
    "is_active": true
  }
]
```

---

### Validate Promo Code (RPC)

```
POST /rest/v1/rpc/validate_promo_code
```

Headers: `apikey`, `Authorization`

Request:
```json
{ "p_code": "SAVE20" }
```

Response `200` (valid):
```json
{
  "valid": true,
  "id": "uuid",
  "code": "SAVE20",
  "discount_type": "percentage",
  "discount_value": 20
}
```

Response `200` (invalid):
```json
{ "valid": false, "error": "invalid_or_expired" }
```

---

### List My Purchases

```
GET /rest/v1/user_purchases?order=created_at.desc&select=*,subscription_plans(name,slug)
```

---

## 13. Notifications `/rest/v1/notifications`

### List All Notifications

```
GET /rest/v1/notifications?order=created_at.desc&select=*
```

---

### List Unread Notifications

```
GET /rest/v1/notifications?is_read=eq.false&order=created_at.desc&select=*
```

---

### Mark Notification as Read

```
PATCH /rest/v1/notifications?id=eq.<notification_id>
```

Headers: `apikey`, `Authorization`

Request:
```json
{ "is_read": true }
```

---

### Mark All Notifications as Read (RPC)

```
POST /rest/v1/rpc/mark_all_notifications_read
```

Headers: `apikey`, `Authorization`

Request: `{}`

Response `200`: Integer count of rows updated.

```json
5
```

---

## 14. Banners `/rest/v1/banners`

### List Active Banners

```
GET /rest/v1/banners?order=display_order&select=*,categories(name,slug),tools(name,slug)
```

RLS restricts to currently active banners within their `valid_from`/`valid_until` window.

Response `200`:
```json
[
  {
    "id": "uuid",
    "title": "New Year Special",
    "description": "...",
    "image_url": "https://...",
    "cta_text": "Get Reading",
    "cta_action": "navigate:tool:uuid",
    "credit_cost": null,
    "display_order": 1,
    "categories": null,
    "tools": { "name": "Life Path", "slug": "life-path" }
  }
]
```

---

## 15. Edge Functions

### Analyze Palm

```
POST /functions/v1/analyze-palm
```

Headers: `apikey`, `Authorization`, `Content-Type: application/json`

Request:
```json
{ "session_id": "uuid" }
```

The session must be in `pending` or `processing` status. The session is created first via `start_tool_session` RPC; then this endpoint is called immediately.

Response `200`:
```json
{ "session_id": "uuid", "status": "completed" }
```

Response `409` (already processed):
```json
{ "error": "Session already in state: completed" }
```

Response `500` (AI failure — credits auto-refunded):
```json
{ "error": "Analysis failed. Credits have been refunded." }
```

---

### Send Chat Message

```
POST /functions/v1/chat
```

Headers: `apikey`, `Authorization`, `Content-Type: application/json`

Request:
```json
{
  "chat_session_id": "uuid",
  "message": "What does my life line say about my health?"
}
```

Response `200`:
```json
{
  "message_id": "uuid",
  "content": "Your life line suggests...",
  "created_at": "2026-03-10T12:00:00Z"
}
```

---

### Process Payment Webhook (Stripe)

```
POST /functions/v1/process-payment
```

Headers (Stripe): `stripe-signature: t=<timestamp>,v1=<hmac>`

Headers (RevenueCat): `x-revenuecat-signature: <base64-hmac>`

Request body: Raw JSON payload from payment provider.

Response `200`:
```json
{ "received": true, "processed": true, "purchase_id": "uuid" }
```

This endpoint is called by the payment provider, not directly by the app.

---

## 16. Storage (Palm Images) `/storage/v1/`

### Upload Palm Image

```
POST /storage/v1/object/palms/<user_id>/<filename>.jpg
```

Headers: `apikey`, `Authorization`, `Content-Type: image/jpeg`

Body: Raw image bytes.

Response `200`:
```json
{ "Key": "palms/<user_id>/<filename>.jpg" }
```

After upload, update the palm record with the public or signed URL.

---

### Get Signed URL for Palm Image

```
POST /storage/v1/object/sign/palms/<path>
```

Headers: `apikey`, `Authorization`

Request:
```json
{ "expiresIn": 3600 }
```

Response `200`:
```json
{ "signedURL": "https://..." }
```

---

## Quick Reference — All Endpoints

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
| 11 | GET | `/rest/v1/palms?id=eq.*` | JWT | Get palm |
| 12 | POST | `/rest/v1/palms` | JWT | Create palm |
| 13 | PATCH | `/rest/v1/palms?id=eq.*` | JWT | Update palm |
| 14 | DELETE | `/rest/v1/palms?id=eq.*` | JWT | Delete palm |
| 15 | GET | `/rest/v1/categories` | JWT | List categories |
| 16 | GET | `/rest/v1/languages` | JWT | List languages |
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
| 43 | POST | `/rest/v1/rpc/validate_promo_code` | JWT | Validate promo |
| 44 | GET | `/rest/v1/user_purchases` | JWT | My purchases |
| 45 | GET | `/rest/v1/notifications` | JWT | All notifications |
| 46 | GET | `/rest/v1/notifications?is_read=eq.false` | JWT | Unread only |
| 47 | PATCH | `/rest/v1/notifications?id=eq.*` | JWT | Mark as read |
| 48 | POST | `/rest/v1/rpc/mark_all_notifications_read` | JWT | Mark all read |
| 49 | GET | `/rest/v1/banners` | JWT | Active banners |
| 50 | POST | `/functions/v1/analyze-palm` | JWT | AI palm analysis |
| 51 | POST | `/functions/v1/chat` | JWT | Chat message |
| 52 | POST | `/functions/v1/process-payment` | HMAC | Payment webhook |
| 53 | POST | `/storage/v1/object/palms/*` | JWT | Upload palm image |
| 54 | POST | `/storage/v1/object/sign/palms/*` | JWT | Get signed URL |
