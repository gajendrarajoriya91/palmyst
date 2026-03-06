-- ============================================================
-- Palmyst — Initial Application Schema
-- ============================================================
-- Sections:
--   1. ENUM Types
--   2. Helper trigger function for updated_at
--   3. Tables  (dependency-ordered)
--   4. Partial unique index (palms.is_self)
--   5. Indexes
--   6. handle_new_user() signup trigger  (5-credit welcome bonus)
--   7. Row Level Security — Enable + Policies (all tables)
-- ============================================================

-- ============================================================
-- SECTION 1: ENUM TYPES
-- ============================================================

CREATE TYPE public.gender_enum AS ENUM (
    'male',
    'female',
    'other',
    'prefer_not_to_say'
);

CREATE TYPE public.session_status AS ENUM (
    'pending',
    'processing',
    'completed',
    'failed'
);

CREATE TYPE public.solution_type AS ENUM (
    'traditional',
    'science_backed'
);

CREATE TYPE public.action_status AS ENUM (
    'locked',
    'available',
    'completed'
);

CREATE TYPE public.reflection_feeling AS ENUM (
    'felt_good',
    'was_uncomfortable',
    'not_sure_yet'
);

CREATE TYPE public.message_role AS ENUM (
    'user',
    'assistant'
);

CREATE TYPE public.credit_type AS ENUM (
    'signup_bonus',
    'tool_usage',
    'solution_unlock',
    'purchase',
    'referral_bonus',
    'review_reward',
    'share_reward',
    'admin_grant',
    'promo_bonus'
);

CREATE TYPE public.discount_type AS ENUM (
    'percentage',
    'fixed'
);

CREATE TYPE public.payment_status AS ENUM (
    'pending',
    'completed',
    'failed',
    'refunded'
);

-- ============================================================
-- SECTION 2: HELPER — updated_at TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- ============================================================
-- SECTION 3: TABLES  (ordered by FK dependencies)
-- ============================================================

-- ------------------------------------------------------------
-- 3.1  languages
--      Lookup table — no updated_at needed.
-- ------------------------------------------------------------
CREATE TABLE public.languages (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name          text        NOT NULL,
    code          text        NOT NULL UNIQUE,          -- ISO 639-1, e.g. "en"
    is_active     boolean     NOT NULL DEFAULT true,
    display_order integer     NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- 3.2  profiles
--      1-to-1 extension of auth.users.
--      Inserted automatically by handle_new_user() trigger.
-- ------------------------------------------------------------
CREATE TABLE public.profiles (
    id                     uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name           text,
    avatar_url             text,
    preferred_language_id  uuid        REFERENCES public.languages(id) ON DELETE SET NULL,
    credit_balance         integer     NOT NULL DEFAULT 0 CHECK (credit_balance >= 0),
    referred_by            uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.3  palms
--      Palm profiles managed by a user.
--      Partial unique index (uq_palms_owner_is_self) added in
--      Section 4 to allow only one is_self = true per owner.
-- ------------------------------------------------------------
CREATE TABLE public.palms (
    id             uuid               PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id       uuid               NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name           text               NOT NULL,
    age            integer            CHECK (age > 0 AND age < 150),
    email          text,
    gender         public.gender_enum,
    palm_image_url text,
    is_self        boolean            NOT NULL DEFAULT false,
    created_at     timestamptz        NOT NULL DEFAULT now(),
    updated_at     timestamptz        NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_palms_updated_at
    BEFORE UPDATE ON public.palms
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.4  categories
--      Life categories grouping tools.
-- ------------------------------------------------------------
CREATE TABLE public.categories (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name          text        NOT NULL,
    slug          text        NOT NULL UNIQUE,
    icon_url      text,
    display_order integer     NOT NULL DEFAULT 0,
    is_active     boolean     NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_categories_updated_at
    BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.5  tool_creators
--      Experts credited on each tool's introduction screen.
-- ------------------------------------------------------------
CREATE TABLE public.tool_creators (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name       text        NOT NULL,
    avatar_url text,
    bio        text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_tool_creators_updated_at
    BEFORE UPDATE ON public.tool_creators
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.6  tools
--      Core AI-powered tools users can purchase and run.
-- ------------------------------------------------------------
CREATE TABLE public.tools (
    id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id        uuid        NOT NULL REFERENCES public.categories(id),
    creator_id         uuid        REFERENCES public.tool_creators(id) ON DELETE SET NULL,
    name               text        NOT NULL,
    slug               text        NOT NULL UNIQUE,
    description        text,
    short_description  text,
    icon_url           text,
    credit_cost        integer     NOT NULL DEFAULT 1 CHECK (credit_cost > 0),
    is_featured        boolean     NOT NULL DEFAULT false,
    is_active          boolean     NOT NULL DEFAULT true,
    min_palms_required integer     NOT NULL DEFAULT 1 CHECK (min_palms_required IN (1, 2)),
    display_order      integer     NOT NULL DEFAULT 0,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_tools_updated_at
    BEFORE UPDATE ON public.tools
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.7  tool_features
--      Bullet-point features shown on the tool detail screen.
--      No updated_at — static marketing content.
-- ------------------------------------------------------------
CREATE TABLE public.tool_features (
    id            uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    tool_id       uuid    NOT NULL REFERENCES public.tools(id) ON DELETE CASCADE,
    title         text    NOT NULL,
    description   text,
    display_order integer NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- 3.8  tool_sessions
--      Every tool run by a user. Core transactional entity.
-- ------------------------------------------------------------
CREATE TABLE public.tool_sessions (
    id            uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       uuid                  NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    tool_id       uuid                  NOT NULL REFERENCES public.tools(id),
    palm1_id      uuid                  NOT NULL REFERENCES public.palms(id),
    palm2_id      uuid                  REFERENCES public.palms(id),
    credits_used  integer               NOT NULL CHECK (credits_used > 0),
    status        public.session_status NOT NULL DEFAULT 'pending',
    overall_score numeric(5,2),
    summary_text  text,
    result_data   jsonb,
    created_at    timestamptz           NOT NULL DEFAULT now(),
    updated_at    timestamptz           NOT NULL DEFAULT now(),
    CONSTRAINT chk_tool_sessions_palms_differ
        CHECK (palm2_id IS NULL OR palm2_id <> palm1_id)
);

CREATE TRIGGER trg_tool_sessions_updated_at
    BEFORE UPDATE ON public.tool_sessions
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.9  tool_session_metrics
--      Per-metric breakdown rows (e.g. "Emotional — 67%").
--      Written by AI backend; no updated_at.
-- ------------------------------------------------------------
CREATE TABLE public.tool_session_metrics (
    id            uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id    uuid         NOT NULL REFERENCES public.tool_sessions(id) ON DELETE CASCADE,
    metric_name   text         NOT NULL,
    score         numeric(5,2) NOT NULL,
    unit          text         NOT NULL DEFAULT '%',
    display_order integer      NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- 3.10  session_solutions
--       Traditional + science-backed solutions per session,
--       gated behind credit unlocking.
--       No updated_at — unlocked_at tracks the state change.
-- ------------------------------------------------------------
CREATE TABLE public.session_solutions (
    id                uuid                 PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id        uuid                 NOT NULL REFERENCES public.tool_sessions(id) ON DELETE CASCADE,
    solution_type     public.solution_type NOT NULL,
    content           text                 NOT NULL,
    is_unlocked       boolean              NOT NULL DEFAULT false,
    credits_to_unlock integer              NOT NULL DEFAULT 0 CHECK (credits_to_unlock >= 0),
    unlocked_at       timestamptz,
    created_at        timestamptz          NOT NULL DEFAULT now(),
    UNIQUE (session_id, solution_type)
);

-- ------------------------------------------------------------
-- 3.11  actionable_plans
--       Plan templates defined at the tool level.
-- ------------------------------------------------------------
CREATE TABLE public.actionable_plans (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    tool_id       uuid        NOT NULL REFERENCES public.tools(id) ON DELETE CASCADE,
    title         text        NOT NULL,
    description   text,
    total_actions integer     NOT NULL DEFAULT 0 CHECK (total_actions >= 0),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_actionable_plans_updated_at
    BEFORE UPDATE ON public.actionable_plans
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.12  plan_actions
--       Sequential actions within a plan.
--       No updated_at — static content managed by service role.
-- ------------------------------------------------------------
CREATE TABLE public.plan_actions (
    id               uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id          uuid    NOT NULL REFERENCES public.actionable_plans(id) ON DELETE CASCADE,
    title            text    NOT NULL,
    why_this_matters text,
    what_you_can_do  text,
    display_order    integer NOT NULL,
    UNIQUE (plan_id, display_order)
);

-- ------------------------------------------------------------
-- 3.13  action_steps
--       Step-by-step instructions under "How to Practice It?".
--       No updated_at — static content.
-- ------------------------------------------------------------
CREATE TABLE public.action_steps (
    id          uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
    action_id   uuid    NOT NULL REFERENCES public.plan_actions(id) ON DELETE CASCADE,
    step_number integer NOT NULL,
    content     text    NOT NULL,
    UNIQUE (action_id, step_number)
);

-- ------------------------------------------------------------
-- 3.14  user_action_progress
--       Per-user, per-session tracking of plan action status.
-- ------------------------------------------------------------
CREATE TABLE public.user_action_progress (
    id                 uuid                      PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            uuid                      NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_id         uuid                      NOT NULL REFERENCES public.tool_sessions(id) ON DELETE CASCADE,
    action_id          uuid                      NOT NULL REFERENCES public.plan_actions(id),
    status             public.action_status      NOT NULL DEFAULT 'locked',
    reflection_feeling public.reflection_feeling,
    reflection_notes   text,
    completed_at       timestamptz,
    created_at         timestamptz               NOT NULL DEFAULT now(),
    updated_at         timestamptz               NOT NULL DEFAULT now(),
    UNIQUE (user_id, session_id, action_id)
);

CREATE TRIGGER trg_user_action_progress_updated_at
    BEFORE UPDATE ON public.user_action_progress
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.15  chat_sessions
--       Conversational sessions (tool-scoped or general).
-- ------------------------------------------------------------
CREATE TABLE public.chat_sessions (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    tool_id         uuid        REFERENCES public.tools(id) ON DELETE SET NULL,
    tool_session_id uuid        REFERENCES public.tool_sessions(id) ON DELETE SET NULL,
    title           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_chat_sessions_updated_at
    BEFORE UPDATE ON public.chat_sessions
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.16  chat_messages
--       Individual messages within a chat session.
--       Messages are immutable after creation — no updated_at.
-- ------------------------------------------------------------
CREATE TABLE public.chat_messages (
    id              uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_session_id uuid                NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    role            public.message_role NOT NULL,
    content         text                NOT NULL,
    is_liked        boolean,               -- NULL = not rated
    created_at      timestamptz         NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- 3.17  credit_transactions
--       Append-only ledger. Never UPDATE or DELETE rows.
-- ------------------------------------------------------------
CREATE TABLE public.credit_transactions (
    id             uuid               PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid               NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount         integer            NOT NULL,           -- positive = earned, negative = spent
    type           public.credit_type NOT NULL,
    description    text,
    reference_id   uuid,              -- polymorphic FK (no DB-level FK; see design rationale)
    reference_type text,              -- e.g. 'tool_session', 'user_purchase'
    balance_after  integer            NOT NULL,           -- snapshot for fast balance reads
    created_at     timestamptz        NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- 3.18  subscription_plans
--       Purchasable credit packs (Free / Basic / Premium).
-- ------------------------------------------------------------
CREATE TABLE public.subscription_plans (
    id               uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    name             text          NOT NULL,
    slug             text          NOT NULL UNIQUE,
    description      text,
    price_usd        numeric(10,2) NOT NULL DEFAULT 0 CHECK (price_usd >= 0),
    currency         text          NOT NULL DEFAULT 'USD',
    credits_included integer       NOT NULL CHECK (credits_included >= 0),
    features         jsonb,
    is_active        boolean       NOT NULL DEFAULT true,
    display_order    integer       NOT NULL DEFAULT 0,
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_subscription_plans_updated_at
    BEFORE UPDATE ON public.subscription_plans
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.19  promo_codes
--       Discount codes applicable at checkout.
-- ------------------------------------------------------------
CREATE TABLE public.promo_codes (
    id             uuid                 PRIMARY KEY DEFAULT gen_random_uuid(),
    code           text                 NOT NULL UNIQUE,
    discount_type  public.discount_type NOT NULL,
    discount_value numeric(10,2)        NOT NULL CHECK (discount_value > 0),
    max_uses       integer              CHECK (max_uses IS NULL OR max_uses > 0),
    used_count     integer              NOT NULL DEFAULT 0 CHECK (used_count >= 0),
    valid_from     timestamptz          NOT NULL,
    valid_until    timestamptz,
    is_active      boolean              NOT NULL DEFAULT true,
    created_at     timestamptz          NOT NULL DEFAULT now(),
    updated_at     timestamptz          NOT NULL DEFAULT now(),
    -- Percentage discounts must be 0–100
    CONSTRAINT chk_promo_percentage_range
        CHECK (discount_type <> 'percentage' OR discount_value <= 100),
    -- Expiry must be after start when both are set
    CONSTRAINT chk_promo_valid_dates
        CHECK (valid_until IS NULL OR valid_until > valid_from)
);

CREATE TRIGGER trg_promo_codes_updated_at
    BEFORE UPDATE ON public.promo_codes
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.20  user_purchases
--       Every in-app purchase transaction record.
-- ------------------------------------------------------------
CREATE TABLE public.user_purchases (
    id                   uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              uuid                  NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    plan_id              uuid                  NOT NULL REFERENCES public.subscription_plans(id),
    promo_code_id        uuid                  REFERENCES public.promo_codes(id) ON DELETE SET NULL,
    amount_paid          numeric(10,2)         NOT NULL CHECK (amount_paid >= 0),
    currency             text                  NOT NULL DEFAULT 'USD',
    discount_amount      numeric(10,2)         NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    payment_status       public.payment_status NOT NULL DEFAULT 'pending',
    payment_provider     text,                 -- e.g. 'stripe', 'razorpay'
    payment_provider_ref text,                 -- provider's transaction ID
    billing_email        text,
    credits_granted      integer               NOT NULL DEFAULT 0 CHECK (credits_granted >= 0),
    created_at           timestamptz           NOT NULL DEFAULT now(),
    updated_at           timestamptz           NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_user_purchases_updated_at
    BEFORE UPDATE ON public.user_purchases
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.21  tool_reviews
--       User reviews for tools; one review per user per tool.
-- ------------------------------------------------------------
CREATE TABLE public.tool_reviews (
    id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    tool_id        uuid        NOT NULL REFERENCES public.tools(id),
    session_id     uuid        REFERENCES public.tool_sessions(id) ON DELETE SET NULL,
    rating         integer     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text    text,
    credits_earned integer     NOT NULL DEFAULT 0 CHECK (credits_earned >= 0),
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, tool_id)
);

CREATE TRIGGER trg_tool_reviews_updated_at
    BEFORE UPDATE ON public.tool_reviews
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.22  banners
--       CMS-managed promotional banners for the home screen.
-- ------------------------------------------------------------
CREATE TABLE public.banners (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    title         text        NOT NULL,
    description   text,
    image_url     text,
    cta_text      text,
    cta_action    text,
    category_id   uuid        REFERENCES public.categories(id) ON DELETE SET NULL,
    tool_id       uuid        REFERENCES public.tools(id) ON DELETE SET NULL,
    credit_cost   integer     CHECK (credit_cost IS NULL OR credit_cost >= 0),
    display_order integer     NOT NULL DEFAULT 0,
    is_active     boolean     NOT NULL DEFAULT true,
    valid_from    timestamptz,
    valid_until   timestamptz,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chk_banners_valid_dates
        CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until > valid_from)
);

CREATE TRIGGER trg_banners_updated_at
    BEFORE UPDATE ON public.banners
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------------
-- 3.23  notifications
--       In-app notification feed per user.
--       No updated_at — only is_read changes, tracked by query.
-- ------------------------------------------------------------
CREATE TABLE public.notifications (
    id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title          text        NOT NULL,
    body           text,
    type           text        NOT NULL,   -- e.g. 'credit_earned', 'session_ready'
    is_read        boolean     NOT NULL DEFAULT false,
    reference_id   uuid,                  -- polymorphic FK
    reference_type text,                  -- e.g. 'tool_session', 'purchase'
    created_at     timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- SECTION 4: PARTIAL UNIQUE INDEX — palms.is_self
-- Only one palm per owner may have is_self = true.
-- ============================================================

CREATE UNIQUE INDEX uq_palms_owner_is_self
    ON public.palms (owner_id)
    WHERE is_self = true;

-- ============================================================
-- SECTION 5: INDEXES
-- ============================================================

-- profiles
CREATE INDEX idx_profiles_credit_balance
    ON public.profiles (credit_balance);

-- palms
CREATE INDEX idx_palms_owner_id
    ON public.palms (owner_id);

-- tools
CREATE INDEX idx_tools_category_id
    ON public.tools (category_id);
CREATE INDEX idx_tools_is_featured
    ON public.tools (is_featured) WHERE is_featured = true;
CREATE INDEX idx_tools_is_active
    ON public.tools (is_active)   WHERE is_active   = true;

-- tool_sessions
CREATE INDEX idx_tool_sessions_user_id
    ON public.tool_sessions (user_id);
CREATE INDEX idx_tool_sessions_tool_id
    ON public.tool_sessions (tool_id);
CREATE INDEX idx_tool_sessions_created_at
    ON public.tool_sessions (created_at DESC);
CREATE INDEX idx_tool_sessions_status
    ON public.tool_sessions (status);

-- tool_session_metrics
CREATE INDEX idx_tool_session_metrics_session_id
    ON public.tool_session_metrics (session_id);

-- session_solutions
CREATE INDEX idx_session_solutions_session_id
    ON public.session_solutions (session_id);

-- user_action_progress
CREATE INDEX idx_user_action_progress_user_id
    ON public.user_action_progress (user_id);
CREATE INDEX idx_user_action_progress_session_id
    ON public.user_action_progress (session_id);

-- chat_sessions
CREATE INDEX idx_chat_sessions_user_id
    ON public.chat_sessions (user_id);
CREATE INDEX idx_chat_sessions_tool_session_id
    ON public.chat_sessions (tool_session_id);

-- chat_messages
CREATE INDEX idx_chat_messages_session_id
    ON public.chat_messages (chat_session_id);
CREATE INDEX idx_chat_messages_created_at
    ON public.chat_messages (created_at ASC);

-- credit_transactions
CREATE INDEX idx_credit_transactions_user_id
    ON public.credit_transactions (user_id);
CREATE INDEX idx_credit_transactions_created_at
    ON public.credit_transactions (created_at DESC);
CREATE INDEX idx_credit_transactions_type
    ON public.credit_transactions (type);

-- user_purchases
CREATE INDEX idx_user_purchases_user_id
    ON public.user_purchases (user_id);
CREATE INDEX idx_user_purchases_status
    ON public.user_purchases (payment_status);

-- tool_reviews
CREATE INDEX idx_tool_reviews_tool_id
    ON public.tool_reviews (tool_id);

-- notifications
CREATE INDEX idx_notifications_user_id
    ON public.notifications (user_id);
CREATE INDEX idx_notifications_unread
    ON public.notifications (user_id, is_read) WHERE is_read = false;

-- banners
CREATE INDEX idx_banners_active_order
    ON public.banners (display_order) WHERE is_active = true;

-- ============================================================
-- SECTION 6: SIGNUP TRIGGER  (handle_new_user)
-- ============================================================
-- Fires after every INSERT on auth.users.
-- Creates the profile row, records a signup_bonus credit
-- transaction, and sets the initial credit_balance (5 credits).
-- Runs as SECURITY DEFINER so it can bypass RLS.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_signup_credits constant integer := 5;
BEGIN
    -- 1. Create the profile row, pulling name/avatar from OAuth
    --    metadata when available.
    INSERT INTO public.profiles (id, display_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'full_name',
            NEW.raw_user_meta_data->>'name'
        ),
        NEW.raw_user_meta_data->>'avatar_url'
    );

    -- 2. Record the signup bonus in the credit ledger.
    INSERT INTO public.credit_transactions (
        user_id,
        amount,
        type,
        description,
        balance_after
    )
    VALUES (
        NEW.id,
        v_signup_credits,
        'signup_bonus',
        'Welcome bonus on account creation',
        v_signup_credits
    );

    -- 3. Set the denormalised balance on the profile.
    UPDATE public.profiles
       SET credit_balance = v_signup_credits
     WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- SECTION 7: ROW LEVEL SECURITY
-- ============================================================
-- Note: the rls_auto_enable event trigger in the base migration
-- already enables RLS on CREATE TABLE. The ALTER TABLE statements
-- below are idempotent and make intent explicit.
--
-- Conventions:
--   • authenticated  — any signed-in user
--   • service_role   — backend / Edge Functions only
--   • Public catalogue tables get SELECT-only policies.
--   • User-owned tables scope reads/writes to auth.uid().
--   • Writes that must go through the backend (e.g. credit
--     ledger, payment status) have no INSERT/UPDATE policy
--     for the authenticated role, forcing service_role usage.
-- ============================================================

-- --------------------------------------------------------
-- 7.1  profiles
-- --------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own"
    ON public.profiles
    FOR SELECT TO authenticated
    USING (auth.uid() = id);

CREATE POLICY "profiles_update_own"
    ON public.profiles
    FOR UPDATE TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);
-- INSERT is handled exclusively by handle_new_user() (SECURITY DEFINER).
-- DELETE cascades from auth.users; no explicit policy needed.

-- --------------------------------------------------------
-- 7.2  palms
-- --------------------------------------------------------
ALTER TABLE public.palms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "palms_select_own"
    ON public.palms
    FOR SELECT TO authenticated
    USING (auth.uid() = owner_id);

CREATE POLICY "palms_insert_own"
    ON public.palms
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "palms_update_own"
    ON public.palms
    FOR UPDATE TO authenticated
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "palms_delete_own"
    ON public.palms
    FOR DELETE TO authenticated
    USING (auth.uid() = owner_id);

-- --------------------------------------------------------
-- 7.3  tool_sessions
-- --------------------------------------------------------
ALTER TABLE public.tool_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tool_sessions_select_own"
    ON public.tool_sessions
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "tool_sessions_insert_own"
    ON public.tool_sessions
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
-- UPDATE/DELETE reserved for service_role (AI result write-back, status updates).

-- --------------------------------------------------------
-- 7.4  tool_session_metrics
--      Written by AI backend only; users read their own.
-- --------------------------------------------------------
ALTER TABLE public.tool_session_metrics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tool_session_metrics_select_own"
    ON public.tool_session_metrics
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1
              FROM public.tool_sessions ts
             WHERE ts.id = session_id
               AND ts.user_id = auth.uid()
        )
    );

-- --------------------------------------------------------
-- 7.5  session_solutions
--      Written by AI backend. Users read and can unlock.
-- --------------------------------------------------------
ALTER TABLE public.session_solutions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "session_solutions_select_own"
    ON public.session_solutions
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1
              FROM public.tool_sessions ts
             WHERE ts.id = session_id
               AND ts.user_id = auth.uid()
        )
    );

CREATE POLICY "session_solutions_update_own"
    ON public.session_solutions
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1
              FROM public.tool_sessions ts
             WHERE ts.id = session_id
               AND ts.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
              FROM public.tool_sessions ts
             WHERE ts.id = session_id
               AND ts.user_id = auth.uid()
        )
    );

-- --------------------------------------------------------
-- 7.6  user_action_progress
-- --------------------------------------------------------
ALTER TABLE public.user_action_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_action_progress_select_own"
    ON public.user_action_progress
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "user_action_progress_insert_own"
    ON public.user_action_progress
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_action_progress_update_own"
    ON public.user_action_progress
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- --------------------------------------------------------
-- 7.7  chat_sessions
-- --------------------------------------------------------
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_sessions_select_own"
    ON public.chat_sessions
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "chat_sessions_insert_own"
    ON public.chat_sessions
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "chat_sessions_update_own"
    ON public.chat_sessions
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "chat_sessions_delete_own"
    ON public.chat_sessions
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- --------------------------------------------------------
-- 7.8  chat_messages
--      Access scoped through owning chat_session.
-- --------------------------------------------------------
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "chat_messages_select_own"
    ON public.chat_messages
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1
              FROM public.chat_sessions cs
             WHERE cs.id = chat_session_id
               AND cs.user_id = auth.uid()
        )
    );

CREATE POLICY "chat_messages_insert_own"
    ON public.chat_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1
              FROM public.chat_sessions cs
             WHERE cs.id = chat_session_id
               AND cs.user_id = auth.uid()
        )
    );

CREATE POLICY "chat_messages_delete_own"
    ON public.chat_messages
    FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1
              FROM public.chat_sessions cs
             WHERE cs.id = chat_session_id
               AND cs.user_id = auth.uid()
        )
    );

-- --------------------------------------------------------
-- 7.9  credit_transactions  (append-only ledger)
--      Users read their own rows.
--      All writes go through service_role (DB functions /
--      Edge Functions) to maintain ledger integrity.
-- --------------------------------------------------------
ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "credit_transactions_select_own"
    ON public.credit_transactions
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- --------------------------------------------------------
-- 7.10  user_purchases
-- --------------------------------------------------------
ALTER TABLE public.user_purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_purchases_select_own"
    ON public.user_purchases
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "user_purchases_insert_own"
    ON public.user_purchases
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
-- UPDATE (payment_status, credits_granted) done by service_role webhook handler.

-- --------------------------------------------------------
-- 7.11  tool_reviews
--       All authenticated users can read reviews (public display).
--       Users can INSERT, UPDATE, and DELETE only their own.
-- --------------------------------------------------------
ALTER TABLE public.tool_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tool_reviews_select_all"
    ON public.tool_reviews
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "tool_reviews_insert_own"
    ON public.tool_reviews
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "tool_reviews_update_own"
    ON public.tool_reviews
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "tool_reviews_delete_own"
    ON public.tool_reviews
    FOR DELETE TO authenticated
    USING (auth.uid() = user_id);

-- --------------------------------------------------------
-- 7.12  notifications
-- --------------------------------------------------------
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own"
    ON public.notifications
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- Users may mark notifications as read (UPDATE is_read only).
-- Deleting notifications is intentionally disallowed from the client.
CREATE POLICY "notifications_update_own"
    ON public.notifications
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- --------------------------------------------------------
-- 7.13  languages  (public read-only catalogue)
-- --------------------------------------------------------
ALTER TABLE public.languages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "languages_select_active"
    ON public.languages
    FOR SELECT TO authenticated
    USING (is_active = true);

-- --------------------------------------------------------
-- 7.14  categories  (public read-only catalogue)
-- --------------------------------------------------------
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "categories_select_active"
    ON public.categories
    FOR SELECT TO authenticated
    USING (is_active = true);

-- --------------------------------------------------------
-- 7.15  tool_creators  (public read-only catalogue)
-- --------------------------------------------------------
ALTER TABLE public.tool_creators ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tool_creators_select"
    ON public.tool_creators
    FOR SELECT TO authenticated
    USING (true);

-- --------------------------------------------------------
-- 7.16  tools  (public read-only catalogue)
-- --------------------------------------------------------
ALTER TABLE public.tools ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tools_select_active"
    ON public.tools
    FOR SELECT TO authenticated
    USING (is_active = true);

-- --------------------------------------------------------
-- 7.17  tool_features  (public read-only)
-- --------------------------------------------------------
ALTER TABLE public.tool_features ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tool_features_select"
    ON public.tool_features
    FOR SELECT TO authenticated
    USING (true);

-- --------------------------------------------------------
-- 7.18  actionable_plans  (public read-only)
-- --------------------------------------------------------
ALTER TABLE public.actionable_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "actionable_plans_select"
    ON public.actionable_plans
    FOR SELECT TO authenticated
    USING (true);

-- --------------------------------------------------------
-- 7.19  plan_actions  (public read-only)
-- --------------------------------------------------------
ALTER TABLE public.plan_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "plan_actions_select"
    ON public.plan_actions
    FOR SELECT TO authenticated
    USING (true);

-- --------------------------------------------------------
-- 7.20  action_steps  (public read-only)
-- --------------------------------------------------------
ALTER TABLE public.action_steps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "action_steps_select"
    ON public.action_steps
    FOR SELECT TO authenticated
    USING (true);

-- --------------------------------------------------------
-- 7.21  subscription_plans  (public read-only)
-- --------------------------------------------------------
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subscription_plans_select_active"
    ON public.subscription_plans
    FOR SELECT TO authenticated
    USING (is_active = true);

-- --------------------------------------------------------
-- 7.22  promo_codes  (authenticated users may validate codes)
-- --------------------------------------------------------
ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "promo_codes_select_active"
    ON public.promo_codes
    FOR SELECT TO authenticated
    USING (
        is_active = true
        AND (valid_until IS NULL OR valid_until > now())
    );

-- --------------------------------------------------------
-- 7.23  banners  (active, within display window)
-- --------------------------------------------------------
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "banners_select_active"
    ON public.banners
    FOR SELECT TO authenticated
    USING (
        is_active = true
        AND (valid_from  IS NULL OR valid_from  <= now())
        AND (valid_until IS NULL OR valid_until >  now())
    );
