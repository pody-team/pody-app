# SPRINT_1_PLAN

## Sprint goal
Make the current Pody stack demoable end-to-end for the first real v1 slice.

## Sprint 1 scope
1. Auth works in backend + app
2. Public content browsing works on stable contracts
3. Creator can generate/refine AI plan and create a show
4. Notifications base works
5. Team can run/demo/test the stack reliably

## Sprint 1 deliverables by owner

### PM
- Freeze sprint scope
- Track daily blockers
- Keep one shared status view
- Escalate founder decisions quickly

### Analyst
- Deliver core flow definitions + acceptance criteria
- Confirm what “done” means for each critical journey

### TechLead
- Approve target contracts for auth/content/AI/notifications
- Flag shortcuts allowed in v1 vs after v1

### Designer
- Deliver lightweight UX fixes for:
  - sign in/up
  - creator flow
  - my shows
  - notifications

### Frontend
- Ship app integration for:
  - sign in/sign up/reset/change password where relevant
  - content home/show/episode/my shows
  - AI create flow and plan interaction
  - notifications inbox/settings

### Backend
- Ship stable service behavior for:
  - identity
  - content
  - AI creator flow
  - notifications
- Ensure migrations/seed path works

### QA
- Smoke test all 4 critical journeys
- Report blockers daily
- Re-test fixed issues before sprint close

### DevOps
- Ensure local/staging boot path works
- Provide env/run instructions
- Confirm logs/health visibility for demo debugging

## Suggested execution order
### Day 1-2
- PM + Analyst + TechLead lock scope and acceptance
- DevOps validates environment boot
- Backend/front-end identify contract gaps

### Day 3-5
- Backend stabilizes APIs
- Frontend integrates critical screens
- Designer resolves UX gaps in critical paths

### Day 6-7
- QA runs smoke + regression
- Backend/frontend fix priority bugs
- PM reviews cut list if scope slips

## Definition of done
- At least one happy path demo exists for listener + creator use
- No unresolved P0 blocker on auth or creator create-show flow
- Setup/run steps are documented enough for team reuse
- Known gaps are listed, not hidden

## Assumptions
- Sprint 1 is about integration and stabilization, not broad feature expansion
- If a domain is partially built but not needed for core v1, it stays out
- If scope pressure appears, UX polish is cut before core flow integrity

## Founder checkpoints needed this sprint
- Approve exact v1 scope line
- Approve auth method set for v1
- Approve draft-vs-publish behavior for creator output
