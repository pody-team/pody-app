# PROJECT_BRIEF

## Project
Pody v1 Upgrade

## Context
Pody currently has a working base across:
- Flutter app with listener + creator screens
- API Gateway
- Identity service
- Content service
- AI service for creator planning/chat
- Notification service

Current code suggests the fastest sensible v1 is **not** a full rebuild. It is a focused upgrade to turn the current base into a coherent, demoable, testable product slice.

## Goal
Ship a usable v1 flow for:
1. user authentication
2. content discovery + playback base
3. creator show creation from AI-assisted planning
4. notification basics
5. deployable, testable environment

## Proposed v1 scope
### In scope
- Email/password + Google sign-in flow that works end-to-end
- Basic account/session management (`me`, sign-out, change password)
- Public content browsing: home, show detail, episode detail, library/my shows
- Creator flow: AI thread -> production plan -> create show draft/published show
- Notification inbox + mark read/settings base
- Gateway routing, docs exposure, health checks
- QA checklist for core user journeys
- Dev/staging deployment path with seed data and runbook

### Out of scope for this wave
- Pricing/final subscription business model
- Full social/news/billing production rollout
- Advanced analytics/recommendation system
- Full editorial workflow beyond the current creator plan -> show creation slice
- Complex role/admin backoffice

## Product statement
Pody v1 should let a user discover content and let a creator sign in, generate a show plan with AI, and create/manage initial shows on top of a stable backend stack.

## Success criteria
- Core auth journey passes on app + backend
- Content APIs and app screens use stable data contracts
- AI creator flow can generate/refine plan and create a show without manual DB edits
- Notification basics work in app and backend
- Local/staging environment can be started reliably by team
- QA can run a single clear regression checklist for v1

## Main workstreams and owners
- PM: scope control, dependency sequencing, founder sync
- Analyst: v1 requirements, flows, acceptance criteria
- TechLead: target architecture, API/data contract decisions, technical guardrails
- Designer: tighten critical UX flows only
- Frontend: app integration for auth/content/creator/notifications
- Backend: complete and stabilize service APIs + DB flows
- QA: regression checklist, pass/fail, bug triage
- DevOps: environment, secrets, deployment, observability baseline

## Assumptions
- Assumption: existing services in repo are the intended foundation for v1, not throwaway prototypes.
- Assumption: content + creator flow is higher priority than unfinished social/news/billing domains.
- Assumption: v1 should optimize for a stable internal/beta release before broader growth features.
- Assumption: current `POST /api/v1/content/shows` behavior can be used in v1 first, then refined later.

## Founder decisions still needed
- Exact sign-in methods required at v1 launch: email/password only vs Google included by default
- Whether creator-created show should start as draft-first or can publish immediately in v1
- Whether pricing/premium/credit logic is in v1 or explicitly deferred
