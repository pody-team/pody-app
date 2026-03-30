# ROADMAP

## Objective
Upgrade the current Pody codebase into a coherent v1 product slice.

## Phase 0 — Alignment and freeze (1-2 days)
- PM: lock v1 scope, dependencies, owners
- Analyst: publish core flows + acceptance criteria
- TechLead: confirm target architecture and v1 API contract boundaries
- Founder: close open product decisions blocking implementation

Exit criteria:
- Brief accepted
- Open questions reduced to a short founder decision list
- Sprint 1 scope frozen

## Phase 1 — Core product baseline (Sprint 1)
Focus: make current auth/content/AI creator flow work end-to-end.

Tracks:
- Auth baseline
- Content contract stabilization
- Creator AI -> show creation flow
- App integration baseline
- QA regression baseline
- Environment/runbook baseline

Exit criteria:
- User can sign up/sign in and load authenticated app state
- Creator can generate/refine a plan and create a show
- Public content flow is demoable
- Core smoke tests and manual QA checklist exist

## Phase 2 — Hardening and UX tightening (Sprint 2)
Focus: remove fragile areas and improve clarity.

Tracks:
- UX tightening for auth, create flow, and my shows
- API error handling + loading/empty states
- Notification polish
- Observability, logs, health checks, deployment stability
- Bug fixing from Sprint 1

Exit criteria:
- Priority P0/P1 bugs closed
- Staging environment is stable enough for repeated demos
- UX friction in key flows reduced

## Phase 3 — Release readiness (Sprint 3)
Focus: make v1 operationally ready.

Tracks:
- Final regression pass
- Seed/demo data readiness
- Release checklist and rollback notes
- Founder review and scope cut if needed

Exit criteria:
- Named v1 scope is complete or consciously cut
- Release checklist approved
- Remaining gaps are documented post-v1 items

## Cross-role ownership map
- PM: plan, sequence, unblock, founder escalation
- Analyst: requirement clarity and acceptance criteria
- TechLead: architecture and technical acceptance bar
- Designer: key UX decisions and handoff
- Frontend: app implementation and integration
- Backend: service/API/data implementation
- QA: verification and bug reporting
- DevOps: environments, deploy, monitoring, secrets

## Roadmap rules
- Keep v1 narrow
- Prefer integration completion over adding new domains
- Do not expand scope into billing/social/news unless founder explicitly re-prioritizes
