# Mutual Fund Purchase Optimizer (MFPO) — Low-Level Design Block Diagram

*Last updated from codebase analysis — March 2026*

---

## Architecture Overview

| Layer | Components | Technology |
|-------|------------|------------|
| **Client** | React SPA (Vite), Nginx | React 18, Vite, Tailwind, Recharts |
| **API Edge** | Nginx reverse proxy | Port 3000 → `/api/*` → backend:8000 |
| **Application** | FastAPI monolith | Python 3.x, FastAPI, SQLAlchemy |
| **Data** | PostgreSQL, local CSVs | Postgres, SQLAlchemy ORM |
| **External** | mfapi.in, Gmail SMTP | REST API, TLS SMTP |

---

## LLD Block Diagram (Mermaid)

```mermaid
flowchart TB
  subgraph Users["Users"]
    Investor["Investor"]
    Advisor["Advisor"]
    Admin["Admin"]
  end

  subgraph ClientLayer["Client Layer"]
    ReactSPA["React SPA (Vite)\n• Home, Signup, Signin\n• VerifyOTP, LoginOTP\n• Forgot/Reset Password\n• ClientDashboard\n• AdvisorDashboard\n• AdminDashboard"]
    Nginx["Nginx (Port 3000)\n• TLS/Proxy\n• /api/* → backend:8000\n• SPA fallback\n• Static asset cache"]
  end

  subgraph FastAPIApp["FastAPI Application (Port 8000)"]
    subgraph AuthModule["Auth & Identity"]
      AuthRouter["auth.py\n/register, /login\n/verify-login-otp\n/refresh, /logout\n/me, /change-password"]
      OTPRouter["otp.py\n/verify-otp\n/resend-otp"]
      PWResetRouter["password_reset.py\n/forgot-password\n/reset-password"]
    end

    subgraph InvestorModule["Investor & Portfolio"]
      InvestorRouter["investor.py\n/profile, /portfolio\n/pending-orders\n/history, /invest\n/invest-all"]
      RiskCalc["RiskCalculatorService\nUserRiskScoreEngine"]
    end

    subgraph FundsModule["Fund Catalogue"]
      FundsRouter["funds.py\n/, /{scheme_code}\n/{scheme_code}/nav"]
    end

    subgraph RecoModule["Recommendation Engine"]
      RecoRouter["recommendations.py\nPOST /"]
    end

    subgraph AdvisorModule["Advisor"]
      AdvisorRouter["advisor.py\n/clients, /orders\n/approve, /reject"]
    end

    subgraph AdminModule["Admin & Ingestion"]
      AdminRouter["admin.py\n/stats, /users\n/funds CRUD\n/ingest/nav\n/ingest/metrics\n/approved-orders"]
      Scheduler["APScheduler\nDaily 01:00"]
      IngestScripts["ingest_mf_data.py\ningest_benchmark_data.py\ncompute_metrics.py"]
    end

    subgraph Core["Core / Cross-cutting"]
      Security["security.py\nJWT, password hash"]
      Crypto["crypto.py\nFernet decrypt"]
      Dependencies["dependencies.py\nget_current_user"]
      EmailSvc["email_service.py\nOTP, reset, order emails"]
    end
  end

  subgraph DataLayer["Data & Infra Layer"]
    Postgres["PostgreSQL\nusers, investor, advisor\nmutual_funds, nav_history, fund_metrics\nportfolio_transactions, benchmarks\n otp, token_blacklist, password_reset"]
    LocalCSV["Local CSV Sources\nBenchmark indices\nTER / expense ratio"]
  end

  subgraph External["External Systems"]
    MFAPI["mfapi.in\nFund metadata & NAV API"]
    SMTP["Gmail SMTP\nEmail delivery"]
  end

  %% User flow
  Users -->|HTTPS| Nginx
  ReactSPA -->|/api/* JSON + Bearer| Nginx
  Nginx -->|Proxy /api → /| FastAPIApp

  %% Auth routing
  AuthRouter --> Security
  AuthRouter --> Crypto
  AuthRouter --> Postgres
  AuthRouter --> EmailSvc
  OTPRouter --> Postgres
  OTPRouter --> EmailSvc
  PWResetRouter --> Crypto
  PWResetRouter --> Postgres
  PWResetRouter --> EmailSvc

  %% Investor routing
  InvestorRouter --> Dependencies
  InvestorRouter --> RiskCalc
  InvestorRouter --> Postgres
  InvestorRouter --> EmailSvc
  RiskCalc --> Postgres

  %% Funds routing
  FundsRouter --> Postgres

  %% Recommendation routing
  RecoRouter --> Postgres
  RecoRouter --> RiskCalc

  %% Advisor routing
  AdvisorRouter --> Postgres
  AdvisorRouter --> EmailSvc

  %% Admin routing
  AdminRouter --> Postgres
  AdminRouter --> IngestScripts
  Scheduler --> IngestScripts
  IngestScripts --> MFAPI
  IngestScripts --> LocalCSV
  IngestScripts --> Postgres

  %% Email
  EmailSvc --> SMTP
```

---

## Request Flow Summary

| Flow | Path | Components |
|------|------|-------------|
| **Signup** | User → Nginx → POST /auth/register | auth.py → User+Investor/Advisor+OTP → email_service |
| **OTP Verify** | POST /auth/verify-otp | otp.py → OTP check → User.is_verified |
| **Login (2FA)** | POST /auth/login → OTP → POST /auth/verify-login-otp | auth.py → JWT tokens |
| **Recommendations** | POST /recommendations/ | recommendations.py → RiskCalc → FundMetrics → allocation |
| **Invest** | POST /investor/invest | investor.py → PortfolioTransaction PENDING → email advisor |
| **Order Approve** | POST /advisor/orders/{id}/approve | advisor.py → status APPROVED → email client |
| **NAV Refresh** | Scheduler 01:00 or POST /admin/ingest/nav | IngestScripts → mfapi.in → nav_history |

---

## Docker Deployment

```
┌─────────────────────────────────────────────────────────────┐
│  docker-compose                                              │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │ frontend:3001   │    │ backend:8000    │                 │
│  │ (Nginx + React) │───▶│ (FastAPI)       │                 │
│  │ /api/* → 8000   │    │ Postgres (env)  │                 │
│  └─────────────────┘    └─────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

---

## File Reference

### Frontend
- `src/main.jsx`, `App.jsx` — Entry, routing, providers
- `src/context/AuthContext.jsx`, `ToastContext.jsx` — State
- `src/services/api.js` — Axios, baseURL `/api`, Bearer + refresh
- `components/ClientDashboard.jsx`, `AdvisorDashboard.jsx`, `AdminDashboard.jsx`
- `nginx.conf` — API proxy, SPA fallback

### Backend
- `src/main.py` — FastAPI app, router includes, scheduler
- `src/api/v1/endpoints/*.py` — auth, otp, password_reset, funds, investor, recommendations, admin, advisor
- `src/core/` — security, crypto, dependencies, User_Risk_Score_Engine, scheduler, config, logger
- `src/services/` — email_service, risk_calculator, user_service
- `scripts/` — ingest_mf_data, ingest_benchmark_data, compute_metrics
