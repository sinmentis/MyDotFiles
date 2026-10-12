---
name: my-standup
description: Draft a short English standup from yesterday's work across Teams, email, Azure DevOps, GitHub, IcM, and local Copilot sessions. Use when asked for my standup, yesterday's work, or today's plan.
---

# My Standup

Gather evidence of the current user's work and draft a concise,
first-person English update. Do not send or post it.

## Time window

- Use the user's local timezone.
- Default to the previous business day. On Monday, use Friday.
- Honor explicit dates or ranges such as "last week."
- Query exact date boundaries, converting to UTC where required.
- Check newer activity only to identify today's follow-ups and avoid
  proposing work that is already complete.

## Gather evidence

Resolve the authenticated user's identity and relevant projects.
Fetch these independent sources in parallel:

- Teams: the user's progress updates, technical discussions,
  decisions, and follow-up commitments.
- Email: the user's work-related replies and commitments, plus
  relevant incoming requests. Receiving an email is not completed work.
- Azure DevOps: work-item changes, comments, and authored or reviewed
  pull requests. Inspect activity, not just current assignment.
- GitHub: authored and reviewed pull requests, commits, and comments.
  Prefer the gh CLI.
- IcM: incidents investigated, updated, or handled by the user.
  Use ops icm for live context and discussion.
- Local Copilot sessions: query local session history for the requested
  window and read relevant outcomes. Exclude personal and unrelated
  sessions.

Discover available authenticated tools before calling them.
Use existing team configuration where available. Do not collect
other team members' activity except as context for the user's work.

## Reconcile

- Combine evidence by workstream and remove duplicate events.
- Attribute only the user's own contributions.
- Distinguish investigation, implementation, review, merge, validation,
  and rollout. An open PR is not shipped work; a merged fix is not
  necessarily deployed.
- Treat Copilot drafts and proposed actions as uncompleted unless
  execution is confirmed.
- Prefer timestamped activity over session titles or ticket summaries.
- Keep source links internally. Link the main work items naturally
  in the output without turning it into a source inventory.
- If a source is unavailable, try a supported alternative. Briefly
  disclose any material coverage gap outside the standup.
- If no work is evidenced, say so. Do not fill gaps with older work.

## Today's plan

Use explicit commitments, current blockers, pending reviews, and
active work to identify the most likely next steps.

When no explicit plan exists, make a conservative proposed plan
from the evidence and label it "Suggested" in the heading.
Do not invent deadlines, approvals, or release decisions.

## Output

Use exactly these two sections, each containing one short paragraph:

**What I did yesterday**
[Two or three concise first-person sentences covering the main
contributions and their actual status.]

**What I will do today**
[One or two concise first-person sentences covering the priorities.]

For an explicit historical range, adjust the first heading.
For an inferred plan, use **What I will do today (Suggested)**.

Aim for 80-120 words total. Use plain, conversational English.
No bullets, names, mentions, emojis, exhaustive PR lists, or filler.
Expand unfamiliar acronyms or use plain-English equivalents.
Do not expose personal information, customer details, or secrets.
