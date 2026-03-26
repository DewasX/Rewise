-- USERS Table
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT auth.uid(),
    name TEXT,
    email TEXT UNIQUE,
    auth_provider TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    daily_available_minutes INTEGER DEFAULT 30,
    preferred_study_time TIME,
    memory_health_score FLOAT DEFAULT 0,
    streak_count INTEGER DEFAULT 0,
    last_active_date DATE,
    device_limit INTEGER DEFAULT 1
);

-- SUBJECTS Table
CREATE TABLE subjects (
    subject_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    subject_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    avg_memory_score FLOAT DEFAULT 0
);

-- TOPICS Table
CREATE TABLE topics (
    topic_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    subject_id UUID REFERENCES subjects(subject_id) ON DELETE CASCADE,
    topic_name TEXT NOT NULL,
    estimated_minutes INTEGER DEFAULT 5,
    difficulty_level INTEGER CHECK (difficulty_level BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_reviewed_at TIMESTAMPTZ,
    next_review_date DATE,
    repetition_count INTEGER DEFAULT 0,
    interval_days INTEGER DEFAULT 0,
    ease_factor FLOAT DEFAULT 2.5,
    stability_value FLOAT DEFAULT 1.0,
    memory_score FLOAT DEFAULT 0,
    overdue_days INTEGER DEFAULT 0,
    status TEXT DEFAULT 'New' CHECK (status IN ('New', 'Strong', 'Stable', 'Fading', 'Urgent'))
);

-- REVIEW_HISTORY Table
CREATE TABLE review_history (
    review_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic_id UUID REFERENCES topics(topic_id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    review_date TIMESTAMPTZ DEFAULT NOW(),
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    interval_before INTEGER,
    interval_after INTEGER,
    retention_before FLOAT,
    retention_after FLOAT
);

-- DAILY_PLAN Table
CREATE TABLE daily_plan (
    plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    date DATE DEFAULT CURRENT_DATE,
    total_available_minutes INTEGER,
    total_scheduled_minutes INTEGER,
    generated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_plan ENABLE ROW LEVEL SECURITY;

-- Basic RLS Policies (Temporarily open to all for MVP testing without Auth)
CREATE POLICY "Allow public all on users" ON users FOR ALL USING (true);
CREATE POLICY "Allow public all on subjects" ON subjects FOR ALL USING (true);
CREATE POLICY "Allow public all on topics" ON topics FOR ALL USING (true);
CREATE POLICY "Allow public all on review_history" ON review_history FOR ALL USING (true);
CREATE POLICY "Allow public all on daily_plan" ON daily_plan FOR ALL USING (true);
