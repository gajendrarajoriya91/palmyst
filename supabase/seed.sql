-- ============================================================
-- Palmyst — Seed Data  (UUID-fixed)
-- Run automatically via: npx supabase db reset --local
-- ============================================================
-- UUID scheme — all chars are valid hex (0-9, a-f):
--   10000000-0000-4000-8000-…  languages
--   20000000-0000-4000-8000-…  categories
--   30000000-0000-4000-8000-…  tool_creators
--   40000000-0000-4000-8000-…  tools
--   50000000-0000-4000-8000-…  tool_features
--   60000000-0000-4000-8000-…  subscription_plans
--   70000000-0000-4000-8000-…  promo_codes
--   80000000-0000-4000-8000-…  actionable_plans
--   90000000-0000-4000-8000-…  plan_actions
--   a0000000-0000-4000-8000-…  action_steps
--   b0000000-0000-4000-8000-…  banners
-- ============================================================

-- ============================================================
-- 1. LANGUAGES
-- ============================================================

INSERT INTO public.languages (id, name, code, is_active, display_order) VALUES
  ('10000000-0000-4000-8000-000000000001', 'English',            'en', true, 1),
  ('10000000-0000-4000-8000-000000000002', 'Arabic',             'ar', true, 2),
  ('10000000-0000-4000-8000-000000000003', 'French',             'fr', true, 3),
  ('10000000-0000-4000-8000-000000000004', 'Spanish',            'es', true, 4),
  ('10000000-0000-4000-8000-000000000005', 'German',             'de', true, 5),
  ('10000000-0000-4000-8000-000000000006', 'Chinese Simplified', 'zh', true, 6),
  ('10000000-0000-4000-8000-000000000007', 'Japanese',           'ja', true, 7),
  ('10000000-0000-4000-8000-000000000008', 'Portuguese',         'pt', true, 8);

-- ============================================================
-- 2. CATEGORIES
-- ============================================================

INSERT INTO public.categories (id, name, slug, icon_url, display_order, is_active, created_at, updated_at) VALUES
  ('20000000-0000-4000-8000-000000000001', 'Relationship',  'relationship',  'https://cdn.palmyst.app/icons/relationship.svg',  1, true, '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00'),
  ('20000000-0000-4000-8000-000000000002', 'Finance',       'finance',       'https://cdn.palmyst.app/icons/finance.svg',       2, true, '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00'),
  ('20000000-0000-4000-8000-000000000003', 'Career',        'career',        'https://cdn.palmyst.app/icons/career.svg',        3, true, '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00'),
  ('20000000-0000-4000-8000-000000000004', 'Health',        'health',        'https://cdn.palmyst.app/icons/health.svg',        4, true, '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00'),
  ('20000000-0000-4000-8000-000000000005', 'Growth',        'growth',        'https://cdn.palmyst.app/icons/growth.svg',        5, true, '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00'),
  ('20000000-0000-4000-8000-000000000006', 'Personal Life', 'personal-life', 'https://cdn.palmyst.app/icons/personal-life.svg', 6, true, '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00');

-- ============================================================
-- 3. TOOL CREATORS
-- ============================================================

INSERT INTO public.tool_creators (id, name, avatar_url, bio, created_at, updated_at) VALUES
  (
    '30000000-0000-4000-8000-000000000001',
    'Dr. Luna Silva',
    'https://cdn.palmyst.app/creators/dr-luna-silva.jpg',
    'Dr. Luna Silva holds a doctorate in transpersonal psychology and has practised palmistry for over 20 years. She combines Eastern hand-reading traditions with modern psychology to deliver insightful, actionable readings.',
    '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00'
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    'Master Chen Wei',
    'https://cdn.palmyst.app/creators/master-chen-wei.jpg',
    'Master Chen Wei is a fifth-generation palm reader trained in traditional Chinese hand analysis. His methodology blends classical Chinese palmistry with contemporary neuropsychological research to reveal deep life patterns.',
    '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00'
  ),
  (
    '30000000-0000-4000-8000-000000000003',
    'Prof. Aria Patel',
    'https://cdn.palmyst.app/creators/prof-aria-patel.jpg',
    'Prof. Aria Patel is a behavioural scientist and certified palmist with a background in Vedic hand analysis. She specialises in career and financial readings, helping clients align their natural strengths with professional growth.',
    '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00'
  ),
  (
    '30000000-0000-4000-8000-000000000004',
    'Dr. James Okonkwo',
    'https://cdn.palmyst.app/creators/dr-james-okonkwo.jpg',
    'Dr. James Okonkwo is a wellness researcher and holistic practitioner who has integrated West African palm-reading traditions with evidence-based coaching. He specialises in health, longevity, and leadership development.',
    '2026-01-15 08:00:00+00', '2026-01-15 08:00:00+00'
  );

-- ============================================================
-- 4. TOOLS
-- ============================================================

INSERT INTO public.tools
  (id, category_id, creator_id, name, slug, description, short_description,
   icon_url, credit_cost, is_featured, is_active, min_palms_required, display_order,
   created_at, updated_at)
VALUES
  (
    '40000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    'Love Path Reading', 'love-path-reading',
    'Discover the hidden secrets of your love life written in the lines and mounts of your palm. Our AI analyses your heart line, fate line, and Venus mount to reveal your romantic tendencies, emotional depth, and relationship patterns that shape your connections.',
    'Unveil your romantic destiny through your palm''s love secrets',
    'https://cdn.palmyst.app/tools/love-path-reading.svg',
    10, true, true, 1, 1,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '40000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000002',
    'Compatibility Reading', 'compatibility-reading',
    'Compare two palms to reveal the depth of compatibility, emotional synchrony, and long-term potential between two people. Our AI cross-analyses both hands to identify complementary traits, friction points, and areas where your connection can deepen.',
    'Discover the unique bond hidden in two palms',
    'https://cdn.palmyst.app/tools/compatibility-reading.svg',
    15, true, true, 2, 2,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '40000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000003',
    'Wealth Forecast', 'wealth-forecast',
    'Your palm holds the map to financial prosperity. The AI analyses your fate line, head line, and Jupiter mount to uncover your relationship with money, natural wealth-building potential, financial strengths, and any subconscious blocks to abundance.',
    'Reveal your financial destiny and wealth-building potential',
    'https://cdn.palmyst.app/tools/wealth-forecast.svg',
    10, false, true, 1, 3,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '40000000-0000-4000-8000-000000000004',
    '20000000-0000-4000-8000-000000000003',
    '30000000-0000-4000-8000-000000000004',
    'Career Destiny', 'career-destiny',
    'Your career path is written in the lines of your dominant hand. The AI reads your head line, fate line, and Mercury mount to identify your professional strengths, ideal industries, leadership style, and the career moves most aligned with your natural abilities.',
    'Uncover your professional strengths and ideal career direction',
    'https://cdn.palmyst.app/tools/career-destiny.svg',
    10, false, true, 1, 4,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '40000000-0000-4000-8000-000000000005',
    '20000000-0000-4000-8000-000000000004',
    '30000000-0000-4000-8000-000000000001',
    'Vitality Check', 'vitality-check',
    'Your life line and health line reveal more than just lifespan — they map your energy reserves, physical resilience, and recovery capacity. This reading provides a personalised vitality assessment and practical guidance for optimising your physical well-being.',
    'Assess your energy levels and physical resilience',
    'https://cdn.palmyst.app/tools/vitality-check.svg',
    8, false, true, 1, 5,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '40000000-0000-4000-8000-000000000006',
    '20000000-0000-4000-8000-000000000005',
    '30000000-0000-4000-8000-000000000002',
    'Life Path Analysis', 'life-path-analysis',
    'Your life line, head line, and the four major mounts together tell the story of your personal evolution. This comprehensive reading reveals your core purpose, natural growth patterns, untapped potential, and the life chapters that lie ahead.',
    'Discover your core purpose and the path to your fullest potential',
    'https://cdn.palmyst.app/tools/life-path-analysis.svg',
    12, true, true, 1, 6,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '40000000-0000-4000-8000-000000000007',
    '20000000-0000-4000-8000-000000000006',
    '30000000-0000-4000-8000-000000000003',
    'Destiny Reading', 'destiny-reading',
    'A holistic reading that maps your personal life tapestry — including your family patterns, social gifts, creative expression, and the legacy you are here to build. This is the most comprehensive single-palm reading available, covering all six life categories in depth.',
    'A complete map of your personal life destiny and legacy',
    'https://cdn.palmyst.app/tools/destiny-reading.svg',
    12, false, true, 1, 7,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '40000000-0000-4000-8000-000000000008',
    '20000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000004',
    'Business Fortune', 'business-fortune',
    'Entrepreneurs and business owners carry the fingerprints of success in their palms. This reading analyses the Mercury mount, Apollo line, and head line to reveal your entrepreneurial strengths, business instincts, risk tolerance, and the ventures most aligned with your natural talents.',
    'Uncover your entrepreneurial gifts and business fortune',
    'https://cdn.palmyst.app/tools/business-fortune.svg',
    10, false, true, 1, 8,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '40000000-0000-4000-8000-000000000009',
    '20000000-0000-4000-8000-000000000003',
    '30000000-0000-4000-8000-000000000001',
    'Leadership Potential', 'leadership-potential',
    'True leadership is a combination of innate traits and developed skills. By comparing two palms — yours and a colleague or partner — this reading reveals leadership dynamics, power balance, complementary strengths, and how to bring out the best in each other.',
    'Reveal the leadership dynamics between two individuals',
    'https://cdn.palmyst.app/tools/leadership-potential.svg',
    15, false, true, 2, 9,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '40000000-0000-4000-8000-000000000010',
    '20000000-0000-4000-8000-000000000004',
    '30000000-0000-4000-8000-000000000002',
    'Longevity Reading', 'longevity-reading',
    'Longevity is not just about the length of your life line — it is about the quality of your vitality across every decade. This reading maps your health patterns, regenerative capacity, and the lifestyle factors encoded in your palm to guide you toward a longer, more vital life.',
    'Map your vitality patterns for a longer, healthier life',
    'https://cdn.palmyst.app/tools/longevity-reading.svg',
    8, false, true, 1, 10,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  );

-- ============================================================
-- 5. TOOL FEATURES  (3 per tool = 30 rows)
-- ============================================================

INSERT INTO public.tool_features (id, tool_id, title, description, display_order) VALUES
  -- Love Path Reading
  ('50000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','Deep Emotional Analysis','AI reads your heart line to reveal your emotional capacity, attachment style, and how you express love',1),
  ('50000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000001','Relationship Pattern Mapping','Identifies recurring patterns from your Venus mount that shape how you connect with partners',2),
  ('50000000-0000-4000-8000-000000000003','40000000-0000-4000-8000-000000000001','Personalised Love Guidance','Specific actionable advice to attract deeper love and build more fulfilling relationships',3),
  -- Compatibility Reading
  ('50000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000002','Cross-Palm Comparison','Simultaneously analyses both palms to find complementary strengths and potential friction points',1),
  ('50000000-0000-4000-8000-000000000005','40000000-0000-4000-8000-000000000002','Compatibility Score','Detailed compatibility breakdown across emotional, intellectual, and physical dimensions',2),
  ('50000000-0000-4000-8000-000000000006','40000000-0000-4000-8000-000000000002','Relationship Growth Plan','Tailored action plan to strengthen your bond and navigate your key differences constructively',3),
  -- Wealth Forecast
  ('50000000-0000-4000-8000-000000000007','40000000-0000-4000-8000-000000000003','Wealth Potential Score','Quantified assessment of your financial aptitude across six key money domains',1),
  ('50000000-0000-4000-8000-000000000008','40000000-0000-4000-8000-000000000003','Money Mindset Insights','Reveals subconscious money beliefs encoded in your head line and Jupiter mount',2),
  ('50000000-0000-4000-8000-000000000009','40000000-0000-4000-8000-000000000003','Financial Action Strategy','Concrete steps to leverage your natural financial strengths and build lasting prosperity',3),
  -- Career Destiny
  ('50000000-0000-4000-8000-000000000010','40000000-0000-4000-8000-000000000004','Strengths Identification','Pinpoints your top professional strengths and the industries where you are most likely to thrive',1),
  ('50000000-0000-4000-8000-000000000011','40000000-0000-4000-8000-000000000004','Leadership Style Profile','Reveals your natural leadership archetype and how to leverage it for maximum professional impact',2),
  ('50000000-0000-4000-8000-000000000012','40000000-0000-4000-8000-000000000004','Career Roadmap','Personalised 30-day career elevation plan based on your palm''s professional indicators',3),
  -- Vitality Check
  ('50000000-0000-4000-8000-000000000013','40000000-0000-4000-8000-000000000005','Energy Level Assessment','Detailed analysis of your physical vitality, stamina reserves, and recovery speed',1),
  ('50000000-0000-4000-8000-000000000014','40000000-0000-4000-8000-000000000005','Health Risk Awareness','Identifies areas of physical vulnerability so you can take proactive preventive steps',2),
  ('50000000-0000-4000-8000-000000000015','40000000-0000-4000-8000-000000000005','Wellness Optimisation Plan','Personalised lifestyle guidance rooted in your palm''s unique vitality indicators',3),
  -- Life Path Analysis
  ('50000000-0000-4000-8000-000000000016','40000000-0000-4000-8000-000000000006','Purpose Discovery','Reveals your core life purpose and the unique gifts you are here to share with the world',1),
  ('50000000-0000-4000-8000-000000000017','40000000-0000-4000-8000-000000000006','Growth Pattern Analysis','Maps the natural cycles of expansion and consolidation in your personal development journey',2),
  ('50000000-0000-4000-8000-000000000018','40000000-0000-4000-8000-000000000006','Potential Activation Plan','Step-by-step guidance to move toward where your palm says you are destined to be',3),
  -- Destiny Reading
  ('50000000-0000-4000-8000-000000000019','40000000-0000-4000-8000-000000000007','Full Life Tapestry','The most comprehensive reading available — covers all six life domains in a single session',1),
  ('50000000-0000-4000-8000-000000000020','40000000-0000-4000-8000-000000000007','Legacy Mapping','Reveals the unique mark you are here to leave on the world and the people around you',2),
  ('50000000-0000-4000-8000-000000000021','40000000-0000-4000-8000-000000000007','Holistic Action Plan','Integrates insights from all six categories into one coherent personal development roadmap',3),
  -- Business Fortune
  ('50000000-0000-4000-8000-000000000022','40000000-0000-4000-8000-000000000008','Entrepreneurial Archetype','Identifies your business personality type and the ventures most suited to your natural talents',1),
  ('50000000-0000-4000-8000-000000000023','40000000-0000-4000-8000-000000000008','Risk Tolerance Profile','Quantifies your natural appetite for risk and reveals how to use it as a competitive advantage',2),
  ('50000000-0000-4000-8000-000000000024','40000000-0000-4000-8000-000000000008','Business Growth Strategy','Actionable steps to align your business decisions with your natural entrepreneurial strengths',3),
  -- Leadership Potential
  ('50000000-0000-4000-8000-000000000025','40000000-0000-4000-8000-000000000009','Dual Leadership Profile','Side-by-side leadership comparison with complementary strengths highlighted',1),
  ('50000000-0000-4000-8000-000000000026','40000000-0000-4000-8000-000000000009','Power Dynamic Insights','Reveals the natural authority balance between two individuals and how to channel it productively',2),
  ('50000000-0000-4000-8000-000000000027','40000000-0000-4000-8000-000000000009','Team Excellence Plan','A collaborative action plan for bringing out the best in each other as leaders',3),
  -- Longevity Reading
  ('50000000-0000-4000-8000-000000000028','40000000-0000-4000-8000-000000000010','Lifespan Quality Index','Multi-dimensional assessment of longevity potential beyond the traditional life line reading',1),
  ('50000000-0000-4000-8000-000000000029','40000000-0000-4000-8000-000000000010','Regenerative Capacity','Reveals your body''s natural ability to heal, recover, and maintain vitality across decades',2),
  ('50000000-0000-4000-8000-000000000030','40000000-0000-4000-8000-000000000010','Longevity Lifestyle Blueprint','Personalised habits and practices linked to your palm''s longevity markers',3);

-- ============================================================
-- 6. SUBSCRIPTION PLANS
-- ============================================================

INSERT INTO public.subscription_plans
  (id, name, slug, description, price_usd, currency, credits_included,
   features, is_active, display_order, created_at, updated_at)
VALUES
  (
    '60000000-0000-4000-8000-000000000001',
    'Starter', 'starter',
    'Perfect for trying out Palmyst. Get a small credit pack to run your first palm reading and explore the app.',
    0.00, 'USD', 10,
    '["10 credits included","Access to all tools","Standard AI analysis","Community support"]'::jsonb,
    true, 1, '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '60000000-0000-4000-8000-000000000002',
    'Basic', 'basic',
    'Our most popular plan. Ideal for regular users who want to explore multiple readings and unlock solutions.',
    4.99, 'USD', 50,
    '["50 credits included","Access to all tools","Enhanced AI analysis","Solution unlocks","Email support","7-day validity"]'::jsonb,
    true, 2, '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    '60000000-0000-4000-8000-000000000003',
    'Premium', 'premium',
    'For dedicated self-discovery practitioners. Maximum value with enough credits to explore the full Palmyst experience.',
    12.99, 'USD', 150,
    '["150 credits included","Access to all tools","Priority AI analysis","All solution unlocks","Action plan access","Priority support","30-day validity","Compatibility readings included"]'::jsonb,
    true, 3, '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  );

-- ============================================================
-- 7. PROMO CODES
-- ============================================================

INSERT INTO public.promo_codes
  (id, code, discount_type, discount_value, max_uses, used_count,
   valid_from, valid_until, is_active, created_at, updated_at)
VALUES
  ('70000000-0000-4000-8000-000000000001','WELCOME20','percentage',20.00, NULL,  0,'2026-01-01 00:00:00+00',NULL,                    true,'2026-01-15 08:00:00+00','2026-01-15 08:00:00+00'),
  ('70000000-0000-4000-8000-000000000002','SAVE10',   'fixed',     10.00,  500, 47,'2026-01-01 00:00:00+00','2026-12-31 23:59:59+00',true,'2026-01-15 08:00:00+00','2026-01-15 08:00:00+00'),
  ('70000000-0000-4000-8000-000000000003','FIRST50',  'percentage',50.00,  100, 23,'2026-01-01 00:00:00+00','2026-06-30 23:59:59+00',true,'2026-01-15 08:00:00+00','2026-01-15 08:00:00+00'),
  ('70000000-0000-4000-8000-000000000004','LAUNCH15', 'percentage',15.00, NULL,112,'2026-01-01 00:00:00+00','2026-03-31 23:59:59+00',true,'2026-01-15 08:00:00+00','2026-01-15 08:00:00+00'),
  ('70000000-0000-4000-8000-000000000005','VIP25',    'percentage',25.00,   50,  8,'2026-02-01 00:00:00+00',NULL,                    true,'2026-01-28 08:00:00+00','2026-01-28 08:00:00+00');

-- ============================================================
-- 8. ACTIONABLE PLANS  (one per tool)
-- ============================================================

INSERT INTO public.actionable_plans (id, tool_id, title, description, total_actions, created_at, updated_at) VALUES
  ('80000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000001','Love Growth Plan',            'A 3-step journey to open your heart and nurture deeper connection in your relationships.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00'),
  ('80000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000002','Harmony Blueprint',           'Three practices to help two people understand their differences and build a lasting bond.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00'),
  ('80000000-0000-4000-8000-000000000003','40000000-0000-4000-8000-000000000003','Wealth Building Plan',        'A structured plan to audit financial habits and build the foundation for lasting prosperity.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00'),
  ('80000000-0000-4000-8000-000000000004','40000000-0000-4000-8000-000000000004','Career Elevation Plan',       'Three focused actions to clarify your career vision and take the strategic steps that move it forward.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00'),
  ('80000000-0000-4000-8000-000000000005','40000000-0000-4000-8000-000000000005','Vitality Boost Plan',         'Assess your energy patterns and build the resilience for a high-vitality life.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00'),
  ('80000000-0000-4000-8000-000000000006','40000000-0000-4000-8000-000000000006','Life Path Journey',           'Reconnect with your purpose and take the first concrete steps toward living your fullest potential.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00'),
  ('80000000-0000-4000-8000-000000000007','40000000-0000-4000-8000-000000000007','Destiny Alignment Plan',      'Reflect on your life story and step fully into the unique path your destiny reveals.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00'),
  ('80000000-0000-4000-8000-000000000008','40000000-0000-4000-8000-000000000008','Business Success Plan',       'Map your business vision and build the network your business needs to flourish.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00'),
  ('80000000-0000-4000-8000-000000000009','40000000-0000-4000-8000-000000000009','Leadership Development Plan', 'Discover your authentic leadership style and lead with a purpose that inspires action.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00'),
  ('80000000-0000-4000-8000-000000000010','40000000-0000-4000-8000-000000000010','Longevity Lifestyle Plan',    'Learn to read your body''s signals and build the wellness practices that support a vibrant life.',3,'2026-01-20 08:00:00+00','2026-01-20 08:00:00+00');

-- ============================================================
-- 9. PLAN ACTIONS  (3 per plan = 30 rows)
-- ============================================================

INSERT INTO public.plan_actions (id, plan_id, title, why_this_matters, what_you_can_do, display_order) VALUES

  -- Plan 1: Love Growth Plan
  ('90000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000001',
   'Open Your Heart',
   'Vulnerability is the foundation of genuine connection. When you allow yourself to be seen, you invite the love your heart line says you are capable of giving and receiving.',
   'Journal for 10 minutes about your ideal relationship, then share one genuine feeling with someone you trust before the end of today.',1),

  ('90000000-0000-4000-8000-000000000002','80000000-0000-4000-8000-000000000001',
   'Communicate Authentically',
   'Clear and honest communication prevents the misunderstandings that erode trust over time. Your head line shows you have the capacity for precise self-expression.',
   'Identify one conversation you have been avoiding. In your next interaction, practise reflecting back what you hear before you respond.',2),

  ('90000000-0000-4000-8000-000000000003','80000000-0000-4000-8000-000000000001',
   'Nurture the Connection',
   'Relationships do not maintain themselves — they need consistent, intentional care to stay vibrant. Your Venus mount reveals deep reserves of warmth to offer.',
   'Plan one quality-time activity with your partner this week. Express one specific thing you genuinely appreciate about them.',3),

  -- Plan 2: Harmony Blueprint
  ('90000000-0000-4000-8000-000000000004','80000000-0000-4000-8000-000000000002',
   'Understand Your Differences',
   'Compatibility is not about being identical — it is about understanding what makes each of you unique. Your cross-palm reading reveals exactly where those differences lie.',
   'List three key differences between you and your partner. Discuss each one with curiosity instead of judgement.',1),

  ('90000000-0000-4000-8000-000000000005','80000000-0000-4000-8000-000000000002',
   'Build a Shared Language',
   'Couples with the strongest bonds develop their own shorthand. This shared language deepens intimacy and builds a unique partnership identity.',
   'Create a list of words that describe your ideal relationship and share it with your partner. Identify three shared values and write them somewhere visible.',2),

  ('90000000-0000-4000-8000-000000000006','80000000-0000-4000-8000-000000000002',
   'Create Lasting Rituals',
   'Rituals transform ordinary moments into meaningful anchors for your relationship. They create safety and belonging that strengthens your bond over time.',
   'Brainstorm three simple weekly rituals you could do together. Commit to one ritual and schedule it into your calendar this week.',3),

  -- Plan 3: Wealth Building Plan
  ('90000000-0000-4000-8000-000000000007','80000000-0000-4000-8000-000000000003',
   'Audit Your Financial Habits',
   'You cannot change what you do not understand. Your fate line shows strong capacity for financial discipline — but first you need an honest picture of where your money goes.',
   'Review the last 30 days of your spending and categorise each expense. Identify three patterns you want to change and write down why each change matters.',1),

  ('90000000-0000-4000-8000-000000000008','80000000-0000-4000-8000-000000000003',
   'Set Intentional Money Goals',
   'Goals without timelines are just wishes. Your Jupiter mount indicates strong ambition — channel that energy into specific, time-bound financial targets.',
   'Write one financial goal for each horizon: 1 month, 6 months, and 1 year. Break the 1-month goal into four weekly milestones.',2),

  ('90000000-0000-4000-8000-000000000009','80000000-0000-4000-8000-000000000003',
   'Build Your Wealth Foundation',
   'Wealth is built through consistent systems, not occasional effort. Your head line shows practical intelligence that can compound small habits into significant results.',
   'Set up an automatic savings transfer, however small. Research one passive income stream aligned with a skill you already have.',3),

  -- Plan 4: Career Elevation Plan
  ('90000000-0000-4000-8000-000000000010','80000000-0000-4000-8000-000000000004',
   'Clarify Your Career Vision',
   'Without a clear destination, all roads lead nowhere. Your fate line points to a distinct professional calling — but you need to articulate it before you can move toward it.',
   'Write a one-paragraph description of your ideal career three years from now. Identify the three biggest gaps between your current role and that vision.',1),

  ('90000000-0000-4000-8000-000000000011','80000000-0000-4000-8000-000000000004',
   'Develop Your Core Strengths',
   'Your greatest professional advantage comes from doubling down on what you do better than anyone else. Your Mercury mount reveals your most commercially valuable talents.',
   'Ask three trusted colleagues to name your top three professional strengths. Find one concrete way to apply each strength in your current role this week.',2),

  ('90000000-0000-4000-8000-000000000012','80000000-0000-4000-8000-000000000004',
   'Take Strategic Action',
   'Clarity without action is just dreaming. Your head line shows strong execution capacity — what is missing is the first deliberate step in the right direction.',
   'Identify the one high-impact project you have been delaying. Break it into three concrete tasks and schedule the first one on your calendar today.',3),

  -- Plan 5: Vitality Boost Plan
  ('90000000-0000-4000-8000-000000000013','80000000-0000-4000-8000-000000000005',
   'Assess Your Energy Levels',
   'You cannot manage what you cannot measure. Your life line reveals natural energy rhythms — learning to work with them instead of against them is the first step to sustained vitality.',
   'Track your energy levels every two hours for three consecutive days. Identify your peak energy window and the one habit that most consistently drains you.',1),

  ('90000000-0000-4000-8000-000000000014','80000000-0000-4000-8000-000000000005',
   'Establish Healthy Routines',
   'How you begin each day sets the tone for everything that follows. Your health line shows strong regenerative capacity that needs to be activated through consistent morning practices.',
   'Design a morning routine of no more than 30 minutes that includes physical movement. Commit to it every day this week and note how it affects your energy.',2),

  ('90000000-0000-4000-8000-000000000015','80000000-0000-4000-8000-000000000005',
   'Strengthen Your Resilience',
   'Vitality includes emotional and mental bounce-back capacity. Your palm indicates a deep reservoir of resilience that can be consciously developed.',
   'Practise a 5-minute breathing exercise each morning for one week. Write down one challenging situation from the past week and the specific strength it revealed in you.',3),

  -- Plan 6: Life Path Journey
  ('90000000-0000-4000-8000-000000000016','80000000-0000-4000-8000-000000000006',
   'Reconnect With Your Purpose',
   'Modern life easily disconnects us from the deeper why behind our choices. Your life line reveals a strong sense of personal direction waiting to be claimed.',
   'Answer in writing: What would I do if I knew I could not fail? Then list three activities that make you lose track of time and leave you fully alive.',1),

  ('90000000-0000-4000-8000-000000000017','80000000-0000-4000-8000-000000000006',
   'Remove Limiting Beliefs',
   'The lines of your palm reflect your potential — but limiting beliefs stop you from accessing it. Your head line shows the intellectual capacity to reframe any story that no longer serves you.',
   'Write down three beliefs that hold you back. Rewrite each as an empowering affirmation that reflects who you are becoming and say it aloud each morning.',2),

  ('90000000-0000-4000-8000-000000000018','80000000-0000-4000-8000-000000000006',
   'Step Into Your Potential',
   'Purpose without action remains a fantasy. Your fate line shows that forward movement — however small — creates momentum that builds on itself over time.',
   'Choose one action your future self would take and do it today. Share your growth intention with one trusted person to create accountability.',3),

  -- Plan 7: Destiny Alignment Plan
  ('90000000-0000-4000-8000-000000000019','80000000-0000-4000-8000-000000000007',
   'Reflect on Your Life Story',
   'Your destiny is not separate from your history — it is built from it. The depth of your life line reveals that your most formative experiences carry the seeds of your greatest contribution.',
   'Write a timeline of your five most defining life moments and what each one taught you. Identify one recurring theme that runs through all of them.',1),

  ('90000000-0000-4000-8000-000000000020','80000000-0000-4000-8000-000000000007',
   'Align Actions With Values',
   'When your daily actions contradict your deepest values, you experience friction and dissatisfaction. Your Apollo line shows you have a clear sense of what truly matters to you.',
   'List your top five personal values in order of importance. Evaluate how well your current daily actions reflect each value and identify the one gap you will close this week.',2),

  ('90000000-0000-4000-8000-000000000021','80000000-0000-4000-8000-000000000007',
   'Embrace Your Unique Path',
   'Your destiny is not someone else''s version of success — it is the unique expression of your specific gifts in the world. Your palm has its own fingerprint, and so does your calling.',
   'Write a personal mission statement in one sentence. Make one decision today guided entirely by this statement.',3),

  -- Plan 8: Business Success Plan
  ('90000000-0000-4000-8000-000000000022','80000000-0000-4000-8000-000000000008',
   'Map Your Business Vision',
   'Successful businesses are built on a clear, compelling vision. Your Mercury mount reveals strong entrepreneurial instincts — give them a specific target to organise around.',
   'Write a one-paragraph description of your business three years from now. Identify your top three ideal customers and what they value most about what you offer.',1),

  ('90000000-0000-4000-8000-000000000023','80000000-0000-4000-8000-000000000008',
   'Identify Opportunities',
   'Every thriving business finds and fills a gap. Your head line shows strong analytical ability — use it to scan your market with fresh eyes and identify what others are missing.',
   'List three market gaps you are positioned to address. Research your top three competitors and note one significant thing each is not doing that you could do better.',2),

  ('90000000-0000-4000-8000-000000000024','80000000-0000-4000-8000-000000000008',
   'Build Your Network',
   'Business grows at the speed of relationships. Your Apollo line indicates natural charisma and the ability to build meaningful professional bonds that open doors.',
   'Identify five people who could positively impact your business and reach out to one of them today with a genuine offer of value.',3),

  -- Plan 9: Leadership Development Plan
  ('90000000-0000-4000-8000-000000000025','80000000-0000-4000-8000-000000000009',
   'Discover Your Leadership Style',
   'Authentic leadership starts with self-awareness. Your cross-palm reading reveals specific leadership traits — strengths to amplify and blind spots to address.',
   'Take one free online leadership assessment and note your top three strengths. Ask two team members how your leadership has positively impacted them recently.',1),

  ('90000000-0000-4000-8000-000000000026','80000000-0000-4000-8000-000000000009',
   'Cultivate Influence',
   'True influence is earned through genuine investment in the people you lead. Your Mercury mount reveals a talent for human connection that creates loyal, high-performing teams.',
   'Identify one team member who is underperforming and schedule a coaching conversation. Give specific positive feedback to one person on your team each day this week.',2),

  ('90000000-0000-4000-8000-000000000027','80000000-0000-4000-8000-000000000009',
   'Lead With Purpose',
   'The most enduring leaders are driven by a purpose larger than themselves. Your fate line indicates that when you lead from conviction, others naturally follow.',
   'Write your personal leadership philosophy in three sentences. Share it with your team and invite honest feedback.',3),

  -- Plan 10: Longevity Lifestyle Plan
  ('90000000-0000-4000-8000-000000000028','80000000-0000-4000-8000-000000000010',
   'Understand Your Body''s Signals',
   'Your body communicates constantly — most people are not listening. Your life line and health line reveal specific areas that need more attention right now.',
   'Keep a body awareness journal for one week, noting sleep quality, energy, digestion, and mood. Identify the one lifestyle factor most correlated with your low-energy days.',1),

  ('90000000-0000-4000-8000-000000000029','80000000-0000-4000-8000-000000000010',
   'Optimise Your Daily Habits',
   'Longevity is built one daily choice at a time. Your Saturn mount reveals a natural capacity for discipline that, applied to your health, can compound into decades of extra vitality.',
   'Log everything you eat for three days without judgement. Replace one processed food or energy-depleting habit with a nourishing alternative for the next 30 days.',2),

  ('90000000-0000-4000-8000-000000000030','80000000-0000-4000-8000-000000000010',
   'Build Long-Term Wellness',
   'Sustainable health thrives through community, accountability, and the integration of physical, mental, social, and spiritual well-being.',
   'Schedule four wellness activities this month: one physical, one mental, one social, and one spiritual. Find an accountability partner and agree to check in weekly.',3);

-- ============================================================
-- 10. ACTION STEPS  (2 per action = 60 rows)
-- ============================================================

INSERT INTO public.action_steps (id, action_id, step_number, content) VALUES

  -- Action 01: Open Your Heart
  ('a0000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001',1,
   'Find a quiet space and spend 10 minutes writing freely about your ideal romantic relationship — what it feels like, what you give, and what you receive. Do not edit yourself.'),
  ('a0000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000001',2,
   'Before the end of today, share one genuine feeling with someone you trust — not a fact or an opinion, but a real emotion. Notice how it feels to be seen.'),

  -- Action 02: Communicate Authentically
  ('a0000000-0000-4000-8000-000000000003','90000000-0000-4000-8000-000000000002',1,
   'Write down the name of one person and one conversation you have been avoiding. Decide on a specific time this week when you will have it.'),
  ('a0000000-0000-4000-8000-000000000004','90000000-0000-4000-8000-000000000002',2,
   'In your next meaningful conversation, practise the reflect-then-respond technique: before sharing your view, summarise what the other person said and ask if you understood correctly.'),

  -- Action 03: Nurture the Connection
  ('a0000000-0000-4000-8000-000000000005','90000000-0000-4000-8000-000000000003',1,
   'Plan one specific quality-time activity with your partner — not just watching TV together, but something that requires shared presence and conversation. Schedule it this week.'),
  ('a0000000-0000-4000-8000-000000000006','90000000-0000-4000-8000-000000000003',2,
   'Tell the person something specific you genuinely appreciate about them — not a general compliment, but something precise and personal that shows you truly see them.'),

  -- Action 04: Understand Your Differences
  ('a0000000-0000-4000-8000-000000000007','90000000-0000-4000-8000-000000000004',1,
   'Separately, each of you writes down three key differences you notice between yourself and the other person. Be honest but kind in your framing.'),
  ('a0000000-0000-4000-8000-000000000008','90000000-0000-4000-8000-000000000004',2,
   'Share your lists with each other and discuss each difference with genuine curiosity, asking: How does this difference actually benefit our relationship?'),

  -- Action 05: Build a Shared Language
  ('a0000000-0000-4000-8000-000000000009','90000000-0000-4000-8000-000000000005',1,
   'Independently write 10 words that describe your ideal relationship, then share your lists and circle the words you both chose.'),
  ('a0000000-0000-4000-8000-000000000010','90000000-0000-4000-8000-000000000005',2,
   'From your combined lists, agree on three shared relationship values and write them somewhere both of you will see regularly.'),

  -- Action 06: Create Lasting Rituals
  ('a0000000-0000-4000-8000-000000000011','90000000-0000-4000-8000-000000000006',1,
   'Each person brainstorms three simple weekly rituals you could do together — morning coffee, an evening walk, a Sunday meal. Share your ideas without immediately evaluating them.'),
  ('a0000000-0000-4000-8000-000000000012','90000000-0000-4000-8000-000000000006',2,
   'Choose one ritual together and add it to both your calendars for this week. After doing it, spend five minutes talking about how it felt.'),

  -- Action 07: Audit Your Financial Habits
  ('a0000000-0000-4000-8000-000000000013','90000000-0000-4000-8000-000000000007',1,
   'Export or review the last 30 days of your bank or card transactions. Group them into categories: essentials, lifestyle, subscriptions, impulse, and investment.'),
  ('a0000000-0000-4000-8000-000000000014','90000000-0000-4000-8000-000000000007',2,
   'Highlight three spending patterns you want to change. For each one, write a single sentence explaining the specific financial goal it is working against.'),

  -- Action 08: Set Intentional Money Goals
  ('a0000000-0000-4000-8000-000000000015','90000000-0000-4000-8000-000000000008',1,
   'Write three financial goals — one achievable in 1 month, one in 6 months, and one in 1 year. Make each goal specific with a number and a date.'),
  ('a0000000-0000-4000-8000-000000000016','90000000-0000-4000-8000-000000000008',2,
   'Break your 1-month goal into four weekly milestones. Write them in your calendar and set a reminder for each Monday morning to review your progress.'),

  -- Action 09: Build Your Wealth Foundation
  ('a0000000-0000-4000-8000-000000000017','90000000-0000-4000-8000-000000000009',1,
   'Open a dedicated savings account if you do not have one, or review your existing one. Set up an automatic transfer for a fixed amount on each payday, however small.'),
  ('a0000000-0000-4000-8000-000000000018','90000000-0000-4000-8000-000000000009',2,
   'Spend 30 minutes researching one passive income stream that aligns with a skill, asset, or knowledge you already have. Write down three specific first steps to explore it further.'),

  -- Action 10: Clarify Your Career Vision
  ('a0000000-0000-4000-8000-000000000019','90000000-0000-4000-8000-000000000010',1,
   'Write a vivid one-paragraph description of your ideal career three years from now. Include your role, industry, the impact you are having, and how you feel about your work.'),
  ('a0000000-0000-4000-8000-000000000020','90000000-0000-4000-8000-000000000010',2,
   'Identify the three most significant gaps between where you are now and that vision. For each gap, write one action that would move you closer to closing it.'),

  -- Action 11: Develop Your Core Strengths
  ('a0000000-0000-4000-8000-000000000021','90000000-0000-4000-8000-000000000011',1,
   'Send a brief message to three trusted colleagues asking: What do you consider my top three professional strengths? Collect their responses without dismissing any of them.'),
  ('a0000000-0000-4000-8000-000000000022','90000000-0000-4000-8000-000000000011',2,
   'For each of the strengths identified, find one specific way to apply it more deliberately in your current role this week. Block time in your calendar for it.'),

  -- Action 12: Take Strategic Action
  ('a0000000-0000-4000-8000-000000000023','90000000-0000-4000-8000-000000000012',1,
   'Identify the one high-impact project or opportunity at work that you have been deferring. Write down exactly why you have been avoiding it and what completing it would change.'),
  ('a0000000-0000-4000-8000-000000000024','90000000-0000-4000-8000-000000000012',2,
   'Break the project into three concrete, specific tasks. Schedule the first task on your calendar today. Commit to doing it before moving on to anything else that morning.'),

  -- Action 13: Assess Your Energy Levels
  ('a0000000-0000-4000-8000-000000000025','90000000-0000-4000-8000-000000000013',1,
   'Set an alarm every two hours for three days. When it goes off, rate your energy from 1 to 10 and write one sentence about what you were doing at that moment.'),
  ('a0000000-0000-4000-8000-000000000026','90000000-0000-4000-8000-000000000013',2,
   'At the end of three days, review your log and identify your natural peak energy window. Also note the one recurring activity most consistently linked to your lowest scores.'),

  -- Action 14: Establish Healthy Routines
  ('a0000000-0000-4000-8000-000000000027','90000000-0000-4000-8000-000000000014',1,
   'Design a morning routine of no more than 30 minutes that includes at least 5 minutes of physical movement. Write it out as a step-by-step sequence you can follow without thinking.'),
  ('a0000000-0000-4000-8000-000000000028','90000000-0000-4000-8000-000000000014',2,
   'Follow your new routine every morning for seven consecutive days. Each evening, write one sentence about how the morning affected the rest of your day.'),

  -- Action 15: Strengthen Your Resilience
  ('a0000000-0000-4000-8000-000000000029','90000000-0000-4000-8000-000000000015',1,
   'Choose a 5-minute breathing or body-scan practice and set it as a non-negotiable morning appointment for the next seven days. Use an app or video if it helps you stay consistent.'),
  ('a0000000-0000-4000-8000-000000000030','90000000-0000-4000-8000-000000000015',2,
   'At the end of each day this week, write about one difficult moment and what it revealed about your capacity to handle challenges. Focus on what you did right, not what went wrong.'),

  -- Action 16: Reconnect With Your Purpose
  ('a0000000-0000-4000-8000-000000000031','90000000-0000-4000-8000-000000000016',1,
   'Find 30 uninterrupted minutes and write your answer to this question in full: What would I do with my life if I knew with certainty that I could not fail?'),
  ('a0000000-0000-4000-8000-000000000032','90000000-0000-4000-8000-000000000016',2,
   'List five activities that consistently make you lose track of time and leave you energised rather than drained. Look for the common thread — it points toward your authentic purpose.'),

  -- Action 17: Remove Limiting Beliefs
  ('a0000000-0000-4000-8000-000000000033','90000000-0000-4000-8000-000000000017',1,
   'Write down three beliefs about yourself that hold you back from living your fullest life. Be specific: name the belief, where it comes from, and the price you have paid for carrying it.'),
  ('a0000000-0000-4000-8000-000000000034','90000000-0000-4000-8000-000000000017',2,
   'For each limiting belief, write a replacement affirmation that reflects who you are choosing to become. Say all three affirmations aloud every morning this week, looking at yourself in a mirror.'),

  -- Action 18: Step Into Your Potential
  ('a0000000-0000-4000-8000-000000000035','90000000-0000-4000-8000-000000000018',1,
   'Ask yourself: What is the one action my future self — already living at full potential — would take today? Write it down and do it before 12 noon.'),
  ('a0000000-0000-4000-8000-000000000036','90000000-0000-4000-8000-000000000018',2,
   'Tell one trusted person about the growth you are committing to. Ask them to check in with you in one week and be honest with you about what they observe.'),

  -- Action 19: Reflect on Your Life Story
  ('a0000000-0000-4000-8000-000000000037','90000000-0000-4000-8000-000000000019',1,
   'Create a simple timeline of your five most defining life moments — positive or challenging. For each one, write what it taught you about yourself and what it cost you.'),
  ('a0000000-0000-4000-8000-000000000038','90000000-0000-4000-8000-000000000019',2,
   'Read your timeline from start to finish and write down the single most recurring theme you notice across all five moments. That theme is likely a cornerstone of your destiny.'),

  -- Action 20: Align Actions With Values
  ('a0000000-0000-4000-8000-000000000039','90000000-0000-4000-8000-000000000020',1,
   'Write your top five personal values in order of importance, then score each one from 1 to 10 based on how well your current daily life actually honours it.'),
  ('a0000000-0000-4000-8000-000000000040','90000000-0000-4000-8000-000000000020',2,
   'Identify your lowest-scoring value and choose one concrete change you will make this week to close the gap between the value you claim and the life you are actually living.'),

  -- Action 21: Embrace Your Unique Path
  ('a0000000-0000-4000-8000-000000000041','90000000-0000-4000-8000-000000000021',1,
   'Write your personal mission statement in a single sentence using this structure: I am here to [specific action] [specific who] so that [specific outcome].'),
  ('a0000000-0000-4000-8000-000000000042','90000000-0000-4000-8000-000000000021',2,
   'Today, make one meaningful decision — about how you spend your time, energy, or resources — guided entirely and consciously by your mission statement. Record the decision and how it felt.'),

  -- Action 22: Map Your Business Vision
  ('a0000000-0000-4000-8000-000000000043','90000000-0000-4000-8000-000000000022',1,
   'Write a vivid one-paragraph description of your business three years from now: what it does, who it serves, the size, the culture, and the impact it has in the world.'),
  ('a0000000-0000-4000-8000-000000000044','90000000-0000-4000-8000-000000000022',2,
   'Identify your top three ideal customers. For each one, write down the single most important thing they value about what you offer and the number one problem they hire you to solve.'),

  -- Action 23: Identify Opportunities
  ('a0000000-0000-4000-8000-000000000045','90000000-0000-4000-8000-000000000023',1,
   'List three market gaps or unmet customer needs in your industry that your skills and position make you uniquely qualified to address. Be specific about the gap, not just the general area.'),
  ('a0000000-0000-4000-8000-000000000046','90000000-0000-4000-8000-000000000023',2,
   'Research your three closest competitors and identify one significant thing each of them is failing to do for their customers. Write down how you could do it better or differently.'),

  -- Action 24: Build Your Network
  ('a0000000-0000-4000-8000-000000000047','90000000-0000-4000-8000-000000000024',1,
   'Write the names of five people — customers, collaborators, or mentors — who could positively impact your business. For one of them, send a genuine specific message today offering real value first.'),
  ('a0000000-0000-4000-8000-000000000048','90000000-0000-4000-8000-000000000024',2,
   'Find one relevant industry event, online forum, or professional community and join it this week. Make one meaningful contribution — a thoughtful question, a useful resource, or a genuine response.'),

  -- Action 25: Discover Your Leadership Style
  ('a0000000-0000-4000-8000-000000000049','90000000-0000-4000-8000-000000000025',1,
   'Take a free leadership assessment online and write down your top three strengths and the two growth areas that appear most consistently across your results.'),
  ('a0000000-0000-4000-8000-000000000050','90000000-0000-4000-8000-000000000025',2,
   'Ask two team members individually: What is one specific way my leadership has helped you do better work? Listen fully without deflecting, defending, or minimising what they share.'),

  -- Action 26: Cultivate Influence
  ('a0000000-0000-4000-8000-000000000051','90000000-0000-4000-8000-000000000026',1,
   'Identify the one team member who is most struggling and schedule a 30-minute conversation focused entirely on understanding their obstacles — not solving them for them.'),
  ('a0000000-0000-4000-8000-000000000052','90000000-0000-4000-8000-000000000026',2,
   'For five consecutive days, give one specific behavioural piece of positive feedback to a different team member each day. Make it precise enough that they could repeat the behaviour on purpose.'),

  -- Action 27: Lead With Purpose
  ('a0000000-0000-4000-8000-000000000053','90000000-0000-4000-8000-000000000027',1,
   'Write your personal leadership philosophy in exactly three sentences: one about your beliefs about people, one about what you stand for as a leader, and one about the legacy you want to leave.'),
  ('a0000000-0000-4000-8000-000000000054','90000000-0000-4000-8000-000000000027',2,
   'Share your leadership philosophy with your team in a meeting or message. Explicitly invite honest feedback and receive it without becoming defensive, taking notes on what resonates with them.'),

  -- Action 28: Understand Your Body's Signals
  ('a0000000-0000-4000-8000-000000000055','90000000-0000-4000-8000-000000000028',1,
   'Each morning for seven days, spend 3 minutes writing four things in a journal: sleep quality out of 10, energy level out of 10, digestion notes, and current mood in one word.'),
  ('a0000000-0000-4000-8000-000000000056','90000000-0000-4000-8000-000000000028',2,
   'At the end of the week, review your entries and identify the single lifestyle factor that most consistently correlates with your lowest-energy days. That is your first priority to address.'),

  -- Action 29: Optimise Your Daily Habits
  ('a0000000-0000-4000-8000-000000000057','90000000-0000-4000-8000-000000000029',1,
   'For three consecutive days, log everything you eat and drink including approximate quantities. Do this without judgement — the goal is data, not shame.'),
  ('a0000000-0000-4000-8000-000000000058','90000000-0000-4000-8000-000000000029',2,
   'Choose one specific processed food, refined sugar source, or energy-depleting habit and replace it with a nourishing alternative for the next 30 days. Put it in your calendar as a commitment.'),

  -- Action 30: Build Long-Term Wellness
  ('a0000000-0000-4000-8000-000000000059','90000000-0000-4000-8000-000000000030',1,
   'Open your calendar and schedule four wellness activities for this month: one that is primarily physical, one mental, one social, and one spiritual. Treat these as non-negotiable appointments.'),
  ('a0000000-0000-4000-8000-000000000060','90000000-0000-4000-8000-000000000030',2,
   'Identify one person in your life who shares your wellness goals or is willing to support them. Reach out today and propose a simple weekly check-in — even a 5-minute text exchange counts.');

-- ============================================================
-- 11. BANNERS
-- ============================================================

INSERT INTO public.banners
  (id, title, description, image_url, cta_text, cta_action,
   category_id, tool_id, credit_cost, display_order, is_active,
   valid_from, valid_until, created_at, updated_at)
VALUES
  (
    'b0000000-0000-4000-8000-000000000001',
    'Discover Your Love Destiny',
    'Start your journey with a Love Path Reading and uncover what your palm says about your romantic future.',
    'https://cdn.palmyst.app/banners/love-destiny.jpg',
    'Read My Palm', 'navigate:tool:40000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    NULL, 1, true,
    '2026-01-01 00:00:00+00', NULL,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    'b0000000-0000-4000-8000-000000000002',
    'Are You and Your Partner Compatible?',
    'Upload both palms for a Compatibility Reading and discover the hidden dynamics shaping your relationship.',
    'https://cdn.palmyst.app/banners/compatibility.jpg',
    'Check Compatibility', 'navigate:tool:40000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    NULL, 2, true,
    '2026-01-01 00:00:00+00', NULL,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    'b0000000-0000-4000-8000-000000000003',
    'Spring Special — 20% Off All Plans',
    'Use code WELCOME20 at checkout and get 20% off any credit pack. Offer valid while promo code is active.',
    'https://cdn.palmyst.app/banners/spring-promo.jpg',
    'Get Credits', 'navigate:plans',
    NULL, NULL,
    NULL, 3, true,
    '2026-03-01 00:00:00+00', '2026-04-30 23:59:59+00',
    '2026-03-01 08:00:00+00', '2026-03-01 08:00:00+00'
  ),
  (
    'b0000000-0000-4000-8000-000000000004',
    'Unlock Your Financial Future',
    'Your wealth potential is written in your palm. Get a Wealth Forecast reading today and discover your path to financial freedom.',
    'https://cdn.palmyst.app/banners/wealth-forecast.jpg',
    'Reveal My Wealth', 'navigate:tool:40000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000003',
    NULL, 4, true,
    '2026-01-01 00:00:00+00', NULL,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    'b0000000-0000-4000-8000-000000000005',
    'Your Career Was Written in Your Hand',
    'Discover the professional strengths your Career Destiny reading reveals and take the steps toward the work you were born to do.',
    'https://cdn.palmyst.app/banners/career-destiny.jpg',
    'Find My Career Path', 'navigate:category:20000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000004',
    NULL, 5, true,
    '2026-01-01 00:00:00+00', NULL,
    '2026-01-20 08:00:00+00', '2026-01-20 08:00:00+00'
  ),
  (
    'b0000000-0000-4000-8000-000000000006',
    'New: Life Path Analysis',
    'Our most comprehensive growth reading is now live. Discover your core purpose and start living the life your palm has always pointed toward.',
    'https://cdn.palmyst.app/banners/life-path.jpg',
    'Start My Journey', 'navigate:tool:40000000-0000-4000-8000-000000000006',
    '20000000-0000-4000-8000-000000000005',
    '40000000-0000-4000-8000-000000000006',
    NULL, 6, true,
    '2026-02-01 00:00:00+00', NULL,
    '2026-02-01 08:00:00+00', '2026-02-01 08:00:00+00'
  );
