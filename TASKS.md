# TASKS

## Program
POD-UPGRADE-001 — Pody v1 Upgrade

## Priority 1 — Must finish for v1

### PM
- [ ] Lock v1 scope and exclusions
- [ ] Publish dependency order across roles
- [ ] Track blockers and decision log
- [ ] Prepare weekly founder summary

### Analyst
- [ ] Define core journeys: auth, browse, create show, notifications
- [ ] Write acceptance criteria per journey
- [ ] Clarify v1 publish/draft behavior for creator flow
- [ ] Mark explicit out-of-scope items

### TechLead
- [ ] Confirm v1 architecture boundary around gateway + services + Flutter app
- [ ] Review auth contract consistency between docs and implementation
- [ ] Review content/AI/create-show data contract
- [ ] Define non-functional minimums: logging, error format, health checks

### Designer
- [ ] Review critical UX flows only: sign in/up, create flow, my shows, notifications
- [ ] Produce lightweight handoff for missing/error/empty states
- [ ] Flag UX debt acceptable after v1

### Frontend
- [ ] Complete app integration for auth flows
- [ ] Connect creator flow to AI thread/plan APIs
- [ ] Connect show creation/my shows flow to content APIs
- [ ] Connect notifications inbox/settings states
- [ ] Add handling for loading/error/empty states in critical screens

### Backend
- [ ] Stabilize identity APIs used by app
- [ ] Stabilize content APIs for home/show/episode/my shows/create show
- [ ] Stabilize AI APIs for thread, plan, and job polling/streaming as needed
- [ ] Stabilize notification APIs for inbox/read/settings
- [ ] Ensure seed/migration path works on clean environment

### QA
- [ ] Build v1 smoke checklist
- [ ] Build regression checklist for auth/content/create/notifications
- [ ] Log defects with reproduce steps and severity
- [ ] Verify fixes before sprint close

### DevOps
- [ ] Validate docker/local stack boot path
- [ ] Document required env/secrets
- [ ] Prepare staging/dev deployment path
- [ ] Add baseline monitoring/log collection guidance

## Priority 2 — Should finish if Sprint 1 is stable
- [ ] Improve gateway readiness checks across services — Owner: DevOps + Backend
- [ ] Tighten creator flow UX copy and empty states — Owner: Designer + Frontend
- [ ] Improve API docs discoverability from gateway root/docs — Owner: TechLead + Backend
- [ ] Add faster smoke automation for key flows — Owner: QA + Frontend + Backend

## Priority 3 — Explicitly defer unless founder reopens scope
- [ ] Billing/subscription production rollout — Owner: Founder decision first
- [ ] Social/news production scope — Owner: Founder decision first
- [ ] Advanced recommendation/personalization — Owner: Analyst/TechLead later
- [ ] Full admin/backoffice — Owner: PM later

## Dependencies
- Analyst + Founder decisions unlock final Sprint 1 scope
- TechLead contract review unlocks frontend/backend convergence
- Backend API stability unlocks QA execution
- DevOps environment stability unlocks repeatable testing/demo

## Current assumptions
- Auth, content, AI, and notifications are the v1 backbone
- Social/news/billing remain non-core for this upgrade wave
- Team should optimize for end-to-end completion, not parallel feature sprawl
