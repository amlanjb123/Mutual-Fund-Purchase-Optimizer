-- 1.USERS
CREATE TABLE users (
    id VARCHAR PRIMARY KEY,
    public_id VARCHAR NOT NULL UNIQUE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100) UNIQUE,
    hashed_password VARCHAR(255),
    role VARCHAR(20),
    phone_number VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX ix_users_public_id ON users(public_id);
CREATE INDEX ix_users_email ON users(email);


-- 2.ADVISOR
CREATE TABLE advisor (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR REFERENCES users(id),
    arn_number VARCHAR,
    date_of_birth DATE
);

CREATE INDEX ix_advisor_id ON advisor(id);

-- 3.INVESTOR
CREATE TABLE investor (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR REFERENCES users(id),
    date_of_birth DATE,
    annual_income NUMERIC,
    risk_profile VARCHAR,
    pan_number VARCHAR,

    q1 INTEGER,
    q2 INTEGER,
    q3 INTEGER,
    q4 INTEGER,
    duration NUMERIC,

    stated_risk_score NUMERIC(6,4),
    risk_capacity_score NUMERIC(6,4),
    revealed_risk_score NUMERIC(6,4),
    final_risk_score NUMERIC(6,4),
    user_type VARCHAR(10) DEFAULT 'New'
);

CREATE INDEX ix_investor_id ON investor(id);


-- 4.BENCHMARK INDEX
CREATE TABLE benchmark_indices (
    id SERIAL PRIMARY KEY,
    index_name VARCHAR(128) NOT NULL UNIQUE,
    csv_filename VARCHAR(256),
    description VARCHAR(512),
    is_active BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_benchmark_indices_index_name ON benchmark_indices(index_name);


-- 5.BENCHMARK HISTORY
CREATE TABLE benchmark_history (
    id BIGSERIAL PRIMARY KEY,
    index_id INTEGER NOT NULL REFERENCES benchmark_indices(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    value NUMERIC(18,5) NOT NULL,
    net_value NUMERIC(18,5),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_benchmark_index_date UNIQUE (index_id, date)
);

CREATE INDEX ix_benchmark_history_index_id ON benchmark_history(index_id);
CREATE INDEX ix_benchmark_history_index_date ON benchmark_history(index_id, date);


-- 6.MUTUAL FUNDS
CREATE TABLE mutual_funds (
    id SERIAL PRIMARY KEY,
    scheme_code INTEGER NOT NULL UNIQUE,
    scheme_name VARCHAR(512) NOT NULL,
    fund_house VARCHAR(256) NOT NULL,
    scheme_type VARCHAR(128),
    scheme_category VARCHAR(256),
    isin_growth VARCHAR(20),
    isin_div_reinvestment VARCHAR(20),
    benchmark_csv VARCHAR(256),
    expense_ratio NUMERIC(6,4),
    expense_ratio_updated_at TIMESTAMP,
    min_investment NUMERIC(12,2),
    fund_category VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_mutual_funds_scheme_code ON mutual_funds(scheme_code);


-- 7.NAV HISTORY
CREATE TABLE nav_history (
    id BIGSERIAL PRIMARY KEY,
    scheme_code INTEGER NOT NULL REFERENCES mutual_funds(scheme_code) ON DELETE CASCADE,
    data__date DATE NOT NULL,
    data__nav NUMERIC(18,5) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_nav_fund_date UNIQUE (scheme_code, data__date)
);

CREATE INDEX ix_nav_history_scheme_code ON nav_history(scheme_code);
CREATE INDEX ix_nav_history_scheme_date ON nav_history(scheme_code, data__date);


-- 8.FUND METRICS
CREATE TABLE fund_metrics (
    id SERIAL PRIMARY KEY,
    scheme_code INTEGER NOT NULL UNIQUE REFERENCES mutual_funds(scheme_code) ON DELETE CASCADE,

    latest_nav NUMERIC(18,5),
    volatility NUMERIC(10,6),
    max_drawdown NUMERIC(10,6),

    cagr NUMERIC(10,6),
    cagr_1y NUMERIC(10,6),
    cagr_3y NUMERIC(10,6),
    cagr_5y NUMERIC(10,6),

    sortino NUMERIC(10,4),
    beta NUMERIC(10,4),
    alpha NUMERIC(10,4),

    fqs NUMERIC(10,4),
    frs NUMERIC(10,4),

    window_used VARCHAR(20),
    observations INTEGER,
    metrics_start_date DATE,
    metrics_end_date DATE,

    benchmark_used VARCHAR(256),

    is_sufficient BOOLEAN DEFAULT TRUE,
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_fund_metrics_scheme_code ON fund_metrics(scheme_code);


-- 9.FUND TER HISTORY
CREATE TABLE fund_ter_history (
    id BIGSERIAL PRIMARY KEY,
    scheme_code INTEGER NOT NULL REFERENCES mutual_funds(scheme_code) ON DELETE CASCADE,
    ter_date DATE NOT NULL,

    direct_base_ter NUMERIC(6,4),
    direct_additional_b NUMERIC(6,4),
    direct_additional_c NUMERIC(6,4),
    direct_gst NUMERIC(6,4),
    direct_total_ter NUMERIC(6,4) NOT NULL,

    regular_base_ter NUMERIC(6,4),
    regular_additional_b NUMERIC(6,4),
    regular_additional_c NUMERIC(6,4),
    regular_gst NUMERIC(6,4),
    regular_total_ter NUMERIC(6,4),

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_ter_fund_date UNIQUE (scheme_code, ter_date)
);

CREATE INDEX ix_fund_ter_scheme_code ON fund_ter_history(scheme_code);
CREATE INDEX ix_fund_ter_scheme_date ON fund_ter_history(scheme_code, ter_date);


-- 10.TOKEN BLACKLIST
CREATE TABLE token_blacklist (
    token VARCHAR PRIMARY KEY,
    blacklisted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_token_blacklist_token ON token_blacklist(token);


-- 11.OTP
CREATE TABLE otp_verification (
    id VARCHAR PRIMARY KEY,
    email VARCHAR NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_otp_email ON otp_verification(email);
CREATE INDEX ix_otp_id ON otp_verification(id);


-- 12.PASSWORD RESET
CREATE TABLE password_reset (
    token VARCHAR PRIMARY KEY,
    user_id VARCHAR NOT NULL REFERENCES users(id),
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_password_reset_token ON password_reset(token);


-- 13.PORTFOLIO TRANSACTIONS
CREATE TABLE portfolio_transactions (
    id SERIAL PRIMARY KEY,
    investor_id VARCHAR NOT NULL REFERENCES investor(id),
    scheme_code INTEGER NOT NULL REFERENCES mutual_funds(scheme_code),

    amount NUMERIC(12,2) NOT NULL,
    nav_at_purchase NUMERIC(12,4) NOT NULL,
    units NUMERIC(14,4) NOT NULL,

    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approval_date TIMESTAMP,
    status VARCHAR NOT NULL DEFAULT 'APPROVED',
    ai_explanation VARCHAR,
    rejection_reason VARCHAR,
    approved_by_advisor_id VARCHAR REFERENCES users(id),
    investment_duration NUMERIC(5,2)
);

CREATE INDEX ix_portfolio_transactions_id ON portfolio_transactions(id);
CREATE INDEX ix_portfolio_transactions_investor_id ON portfolio_transactions(investor_id);
CREATE INDEX ix_portfolio_transactions_scheme_code ON portfolio_transactions(scheme_code);