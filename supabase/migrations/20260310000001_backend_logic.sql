-- ============================================================
-- Palmyst — Backend Business Logic
-- Triggers · RPC Functions · Security Grants
-- ============================================================

-- ============================================================
-- 1. EXTEND ENUMS
-- ============================================================

ALTER TYPE public.credit_type ADD VALUE IF NOT EXISTS 'tool_refund';

-- ============================================================
-- 2. INTERNAL CREDIT HELPERS
--    SECURITY DEFINER — never exposed as RPC.
--    Access revoked from public/authenticated.
-- ============================================================

CREATE OR REPLACE FUNCTION public.internal_deduct_credits(
    p_user_id  uuid,
    p_amount   int,
    p_type     public.credit_type,
    p_desc     text,
    p_ref_id   uuid DEFAULT NULL,
    p_ref_type text DEFAULT NULL
) RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_balance int;
BEGIN
    UPDATE profiles
       SET credit_balance = credit_balance - p_amount
     WHERE id = p_user_id
       AND credit_balance >= p_amount
     RETURNING credit_balance INTO v_balance;

    IF v_balance IS NULL THEN
        IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = p_user_id) THEN
            RAISE EXCEPTION 'profile_not_found';
        END IF;
        RAISE EXCEPTION 'insufficient_credits';
    END IF;

    INSERT INTO credit_transactions(
        user_id, amount, type, description,
        reference_id, reference_type, balance_after
    ) VALUES (
        p_user_id, -p_amount, p_type, p_desc,
        p_ref_id, p_ref_type, v_balance
    );

    RETURN v_balance;
END;
$$;

REVOKE ALL ON FUNCTION public.internal_deduct_credits(uuid, int, public.credit_type, text, uuid, text) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.internal_grant_credits(
    p_user_id  uuid,
    p_amount   int,
    p_type     public.credit_type,
    p_desc     text,
    p_ref_id   uuid DEFAULT NULL,
    p_ref_type text DEFAULT NULL
) RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_balance int;
BEGIN
    UPDATE profiles
       SET credit_balance = credit_balance + p_amount
     WHERE id = p_user_id
     RETURNING credit_balance INTO v_balance;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'profile_not_found';
    END IF;

    INSERT INTO credit_transactions(
        user_id, amount, type, description,
        reference_id, reference_type, balance_after
    ) VALUES (
        p_user_id, p_amount, p_type, p_desc,
        p_ref_id, p_ref_type, v_balance
    );

    RETURN v_balance;
END;
$$;

REVOKE ALL ON FUNCTION public.internal_grant_credits(uuid, int, public.credit_type, text, uuid, text) FROM PUBLIC;

-- ============================================================
-- 3. TRIGGER FUNCTIONS
-- ============================================================

-- 3a. Initialize user_action_progress when session completes
CREATE OR REPLACE FUNCTION public.fn_init_action_progress()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_plan_id    uuid;
    v_first_id   uuid;
    v_action     record;
BEGIN
    IF OLD.status = NEW.status OR NEW.status <> 'completed' THEN
        RETURN NEW;
    END IF;

    SELECT id INTO v_plan_id
      FROM actionable_plans
     WHERE tool_id = NEW.tool_id
     LIMIT 1;

    IF v_plan_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT id INTO v_first_id
      FROM plan_actions
     WHERE plan_id = v_plan_id
     ORDER BY display_order ASC
     LIMIT 1;

    FOR v_action IN
        SELECT id
          FROM plan_actions
         WHERE plan_id = v_plan_id
         ORDER BY display_order ASC
    LOOP
        INSERT INTO user_action_progress(user_id, session_id, action_id, status)
        VALUES (
            NEW.user_id,
            NEW.id,
            v_action.id,
            CASE WHEN v_action.id = v_first_id
                 THEN 'available'::action_status
                 ELSE 'locked'::action_status
            END
        )
        ON CONFLICT (user_id, session_id, action_id) DO NOTHING;
    END LOOP;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_init_action_progress
    AFTER UPDATE ON public.tool_sessions
    FOR EACH ROW EXECUTE FUNCTION public.fn_init_action_progress();

-- 3b. Create notification on session status transition
CREATE OR REPLACE FUNCTION public.fn_notify_session_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    IF NEW.status = 'completed' THEN
        INSERT INTO notifications(user_id, title, body, type, reference_id, reference_type)
        VALUES (
            NEW.user_id,
            'Your palm reading is ready',
            'Your analysis is complete. Tap to view your insights.',
            'session_completed',
            NEW.id,
            'tool_session'
        );
    ELSIF NEW.status = 'failed' THEN
        INSERT INTO notifications(user_id, title, body, type, reference_id, reference_type)
        VALUES (
            NEW.user_id,
            'Analysis could not be completed',
            'Something went wrong with your reading. Your credits have been refunded.',
            'session_failed',
            NEW.id,
            'tool_session'
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_session_status
    AFTER UPDATE ON public.tool_sessions
    FOR EACH ROW EXECUTE FUNCTION public.fn_notify_session_status();

-- 3c. Refund credits when session transitions to 'failed'
CREATE OR REPLACE FUNCTION public.fn_refund_on_failure()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.status = NEW.status
       OR NEW.status <> 'failed'
       OR OLD.status NOT IN ('pending', 'processing')
    THEN
        RETURN NEW;
    END IF;

    PERFORM public.internal_grant_credits(
        NEW.user_id,
        NEW.credits_used,
        'tool_refund',
        'Refund: palm analysis failed',
        NEW.id,
        'tool_session'
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_refund_on_failure
    AFTER UPDATE ON public.tool_sessions
    FOR EACH ROW EXECUTE FUNCTION public.fn_refund_on_failure();

-- 3d. Grant credits when purchase payment completes
CREATE OR REPLACE FUNCTION public.fn_grant_credits_on_purchase()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.payment_status = NEW.payment_status
       OR NEW.payment_status <> 'completed'
    THEN
        RETURN NEW;
    END IF;

    PERFORM public.internal_grant_credits(
        NEW.user_id,
        NEW.credits_granted,
        'purchase',
        'Credits from subscription purchase',
        NEW.id,
        'user_purchase'
    );

    INSERT INTO notifications(user_id, title, body, type, reference_id, reference_type)
    VALUES (
        NEW.user_id,
        'Credits added to your account',
        format('%s credits have been added to your account.', NEW.credits_granted),
        'purchase_completed',
        NEW.id,
        'user_purchase'
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_grant_credits_on_purchase
    AFTER UPDATE ON public.user_purchases
    FOR EACH ROW EXECUTE FUNCTION public.fn_grant_credits_on_purchase();

-- 3e. Increment promo code usage count on purchase insert
CREATE OR REPLACE FUNCTION public.fn_increment_promo_usage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.promo_code_id IS NULL THEN
        RETURN NEW;
    END IF;

    UPDATE promo_codes
       SET used_count = used_count + 1
     WHERE id = NEW.promo_code_id;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_increment_promo_usage
    AFTER INSERT ON public.user_purchases
    FOR EACH ROW EXECUTE FUNCTION public.fn_increment_promo_usage();

-- 3f. Grant review reward credits on first review (BEFORE INSERT)
CREATE OR REPLACE FUNCTION public.fn_grant_review_credits()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_reward constant int := 3;
BEGIN
    NEW.credits_earned := v_reward;

    PERFORM public.internal_grant_credits(
        NEW.user_id,
        v_reward,
        'review_reward',
        'Credits for submitting a tool review',
        NEW.tool_id,
        'tool'
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_review_credits
    BEFORE INSERT ON public.tool_reviews
    FOR EACH ROW EXECUTE FUNCTION public.fn_grant_review_credits();

-- ============================================================
-- 4. RPC FUNCTIONS  (exposed via PostgREST /rpc/*)
-- ============================================================

-- 4a. Start a tool session — validates credits and palm ownership,
--     deducts credits, creates session atomically.
CREATE OR REPLACE FUNCTION public.start_tool_session(
    p_tool_id  uuid,
    p_palm1_id uuid,
    p_palm2_id uuid DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid  uuid := auth.uid();
    v_tool record;
    v_sid  uuid;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    SELECT id, credit_cost, min_palms_required, is_active
      INTO v_tool
      FROM tools
     WHERE id = p_tool_id;

    IF NOT FOUND OR NOT v_tool.is_active THEN
        RAISE EXCEPTION 'tool_not_found';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM palms WHERE id = p_palm1_id AND owner_id = v_uid
    ) THEN
        RAISE EXCEPTION 'invalid_palm';
    END IF;

    IF v_tool.min_palms_required = 2 THEN
        IF p_palm2_id IS NULL THEN
            RAISE EXCEPTION 'second_palm_required';
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM palms WHERE id = p_palm2_id AND owner_id = v_uid
        ) THEN
            RAISE EXCEPTION 'invalid_palm';
        END IF;
    END IF;

    PERFORM public.internal_deduct_credits(
        v_uid,
        v_tool.credit_cost,
        'tool_usage',
        'Palm reading analysis',
        p_tool_id,
        'tool'
    );

    INSERT INTO tool_sessions(user_id, tool_id, palm1_id, palm2_id, credits_used, status)
    VALUES (v_uid, p_tool_id, p_palm1_id, p_palm2_id, v_tool.credit_cost, 'pending')
    RETURNING id INTO v_sid;

    RETURN v_sid;
END;
$$;

-- 4b. Unlock a session solution — deducts credits, returns content
CREATE OR REPLACE FUNCTION public.unlock_solution(
    p_session_id    uuid,
    p_solution_type public.solution_type
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_sol record;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM tool_sessions
         WHERE id = p_session_id
           AND user_id = v_uid
           AND status = 'completed'
    ) THEN
        RAISE EXCEPTION 'session_not_found';
    END IF;

    SELECT * INTO v_sol
      FROM session_solutions
     WHERE session_id = p_session_id
       AND solution_type = p_solution_type;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'solution_not_found';
    END IF;

    IF v_sol.is_unlocked THEN
        RETURN json_build_object(
            'id', v_sol.id,
            'content', v_sol.content,
            'is_unlocked', true,
            'unlocked_at', v_sol.unlocked_at
        );
    END IF;

    PERFORM public.internal_deduct_credits(
        v_uid,
        v_sol.credits_to_unlock,
        'solution_unlock',
        'Unlock palm reading solution',
        v_sol.id,
        'session_solution'
    );

    UPDATE session_solutions
       SET is_unlocked = true, unlocked_at = now()
     WHERE id = v_sol.id
     RETURNING * INTO v_sol;

    RETURN json_build_object(
        'id', v_sol.id,
        'content', v_sol.content,
        'is_unlocked', true,
        'unlocked_at', v_sol.unlocked_at
    );
END;
$$;

-- 4c. Validate a promo code
CREATE OR REPLACE FUNCTION public.validate_promo_code(p_code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_promo record;
BEGIN
    SELECT * INTO v_promo
      FROM promo_codes
     WHERE code = upper(trim(p_code))
       AND is_active = true
       AND (valid_from  IS NULL OR valid_from  <= now())
       AND (valid_until IS NULL OR valid_until >  now())
       AND (max_uses    IS NULL OR used_count  <  max_uses);

    IF NOT FOUND THEN
        RETURN json_build_object('valid', false, 'error', 'invalid_or_expired');
    END IF;

    RETURN json_build_object(
        'valid',          true,
        'id',             v_promo.id,
        'code',           v_promo.code,
        'discount_type',  v_promo.discount_type,
        'discount_value', v_promo.discount_value
    );
END;
$$;

-- 4d. Submit or update a tool review
--     New review triggers credit grant via fn_grant_review_credits.
--     Update does not re-earn credits.
CREATE OR REPLACE FUNCTION public.submit_review(
    p_tool_id     uuid,
    p_rating      int,
    p_review_text text DEFAULT NULL,
    p_session_id  uuid DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid     uuid := auth.uid();
    v_review  record;
    v_is_new  bool := false;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'invalid_rating';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tools WHERE id = p_tool_id AND is_active = true) THEN
        RAISE EXCEPTION 'tool_not_found';
    END IF;

    IF EXISTS (SELECT 1 FROM tool_reviews WHERE user_id = v_uid AND tool_id = p_tool_id) THEN
        UPDATE tool_reviews
           SET rating      = p_rating,
               review_text = p_review_text,
               session_id  = COALESCE(p_session_id, session_id)
         WHERE user_id = v_uid AND tool_id = p_tool_id
         RETURNING * INTO v_review;
    ELSE
        v_is_new := true;
        INSERT INTO tool_reviews(user_id, tool_id, session_id, rating, review_text)
        VALUES (v_uid, p_tool_id, p_session_id, p_rating, p_review_text)
        RETURNING * INTO v_review;
    END IF;

    RETURN json_build_object(
        'id',             v_review.id,
        'rating',         v_review.rating,
        'credits_earned', CASE WHEN v_is_new THEN v_review.credits_earned ELSE 0 END,
        'is_new_review',  v_is_new
    );
END;
$$;

-- 4e. Complete an action step, unlock the next one
CREATE OR REPLACE FUNCTION public.advance_action(
    p_progress_id uuid,
    p_feeling     public.reflection_feeling DEFAULT NULL,
    p_notes       text                      DEFAULT NULL
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid          uuid := auth.uid();
    v_progress     record;
    v_action       record;
    v_next_id      uuid;
    v_next_prog_id uuid;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    SELECT * INTO v_progress
      FROM user_action_progress
     WHERE id = p_progress_id AND user_id = v_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'progress_not_found';
    END IF;

    IF v_progress.status = 'locked'    THEN RAISE EXCEPTION 'action_locked';     END IF;
    IF v_progress.status = 'completed' THEN RAISE EXCEPTION 'already_completed'; END IF;

    SELECT * INTO v_action FROM plan_actions WHERE id = v_progress.action_id;

    SELECT pa.id INTO v_next_id
      FROM plan_actions pa
     WHERE pa.plan_id = v_action.plan_id
       AND pa.display_order > v_action.display_order
     ORDER BY pa.display_order ASC
     LIMIT 1;

    UPDATE user_action_progress
       SET status             = 'completed',
           reflection_feeling = p_feeling,
           reflection_notes   = p_notes,
           completed_at       = now()
     WHERE id = p_progress_id;

    IF v_next_id IS NOT NULL THEN
        UPDATE user_action_progress
           SET status = 'available'
         WHERE user_id   = v_uid
           AND session_id = v_progress.session_id
           AND action_id  = v_next_id
         RETURNING id INTO v_next_prog_id;
    END IF;

    RETURN json_build_object(
        'completed',  p_progress_id,
        'next',       v_next_prog_id,
        'has_next',   v_next_id IS NOT NULL
    );
END;
$$;

-- 4f. Mark all unread notifications as read, return count updated
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid   uuid := auth.uid();
    v_count int;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    UPDATE notifications
       SET is_read = true
     WHERE user_id = v_uid
       AND is_read = false;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

-- 4g. Record a share reward (rate-limited: once per tool per 24 h)
CREATE OR REPLACE FUNCTION public.record_share_reward(p_tool_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid     uuid := auth.uid();
    v_reward  constant int := 2;
    v_balance int;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    IF EXISTS (
        SELECT 1 FROM credit_transactions
         WHERE user_id       = v_uid
           AND type          = 'share_reward'
           AND reference_id  = p_tool_id
           AND reference_type = 'tool'
           AND created_at    > now() - interval '24 hours'
    ) THEN
        RETURN json_build_object('rewarded', false, 'reason', 'already_rewarded_today');
    END IF;

    v_balance := public.internal_grant_credits(
        v_uid, v_reward, 'share_reward',
        'Credits for sharing a tool', p_tool_id, 'tool'
    );

    RETURN json_build_object(
        'rewarded',       true,
        'credits_earned', v_reward,
        'balance',        v_balance
    );
END;
$$;

-- 4h. Return current credit balance + last 20 transactions
CREATE OR REPLACE FUNCTION public.get_my_credits()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid     uuid := auth.uid();
    v_balance int;
    v_txns    json;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not_authenticated';
    END IF;

    SELECT credit_balance INTO v_balance FROM profiles WHERE id = v_uid;

    SELECT json_agg(t ORDER BY t.created_at DESC) INTO v_txns
      FROM (
          SELECT id, amount, type, description, balance_after, created_at
            FROM credit_transactions
           WHERE user_id = v_uid
           ORDER BY created_at DESC
           LIMIT 20
      ) t;

    RETURN json_build_object(
        'balance',             v_balance,
        'recent_transactions', COALESCE(v_txns, '[]'::json)
    );
END;
$$;

-- ============================================================
-- 5. REPLACE handle_new_user — add referral bonus logic
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_name         text;
    v_avatar       text;
    v_referred_by  uuid;
    v_signup_creds constant int := 5;
    v_ref_creds    constant int := 10;
BEGIN
    v_name := COALESCE(
        NEW.raw_user_meta_data ->> 'full_name',
        NEW.raw_user_meta_data ->> 'name',
        split_part(NEW.email, '@', 1)
    );

    v_avatar := COALESCE(
        NEW.raw_user_meta_data ->> 'avatar_url',
        NEW.raw_user_meta_data ->> 'picture'
    );

    BEGIN
        v_referred_by := (NEW.raw_user_meta_data ->> 'referred_by')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
        v_referred_by := NULL;
    END;

    IF v_referred_by IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM profiles WHERE id = v_referred_by)
    THEN
        v_referred_by := NULL;
    END IF;

    INSERT INTO profiles(id, display_name, avatar_url, credit_balance, referred_by)
    VALUES (NEW.id, v_name, v_avatar, v_signup_creds, v_referred_by);

    INSERT INTO credit_transactions(user_id, amount, type, description, balance_after)
    VALUES (NEW.id, v_signup_creds, 'signup_bonus', 'Welcome bonus on account creation', v_signup_creds);

    IF v_referred_by IS NOT NULL THEN
        PERFORM public.internal_grant_credits(
            v_referred_by, v_ref_creds, 'referral_bonus',
            'Referral bonus for new user signup', NEW.id, 'profile'
        );

        INSERT INTO notifications(user_id, title, body, type, reference_id, reference_type)
        VALUES (
            v_referred_by,
            'Referral bonus!',
            format('A friend joined using your link. You earned %s credits!', v_ref_creds),
            'referral_bonus',
            NEW.id,
            'profile'
        );
    END IF;

    RETURN NEW;
END;
$$;

-- ============================================================
-- 6. GRANTS — RPC functions accessible by authenticated role
-- ============================================================

GRANT EXECUTE ON FUNCTION public.start_tool_session(uuid, uuid, uuid)                           TO authenticated;
GRANT EXECUTE ON FUNCTION public.unlock_solution(uuid, public.solution_type)                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_promo_code(text)                                      TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_review(uuid, int, text, uuid)                           TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_action(uuid, public.reflection_feeling, text)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read()                                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_share_reward(uuid)                                      TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_credits()                                               TO authenticated;
