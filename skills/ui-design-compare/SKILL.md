---
name: ui-design-compare
description: Use when the user wants to see or compare UI mockups, wireframes, layouts, color schemes, visual directions, or frontend design options in a browser before implementation.
---

# UI Design Compare

Turn a visual design decision into a small set of browser-rendered options the
user can compare and select.

This skill is deliberately narrow. It does not require a product spec, an
implementation plan, test-driven development, or sub-agents.

## When to Run

- Run immediately when the user explicitly asks to see, mock up, or compare UI
  options.
- For a general UI design request, use it only when seeing alternatives would
  make the decision clearer than describing them.
- Do not use it for text-only requirements, API design, data modeling, or a
  straightforward implementation with no unresolved visual choice.

## Process

1. Inspect only the existing UI, brand assets, and constraints needed for the
   visual question.
2. Frame one visual decision and create 2-4 materially different options.
   Compare structure, hierarchy, density, navigation, typography, color, or
   interaction model—not cosmetic variations of the same layout.
3. Read [`REFERENCE.md`](REFERENCE.md), start the browser companion, and write a
   new HTML fragment into its `screen_dir`.
4. Give the user the complete keyed URL and a one-sentence description of what
   is being compared. End the turn so they can inspect it.
5. On the next turn, read `state_dir/events` when present and combine the click
   history with the user's terminal feedback.
6. Iterate with a new filename when feedback changes the design. Do not
   overwrite an earlier screen.
7. Stop once the user has selected a direction or no longer needs a visual
   comparison. Do not implement the selected design unless they also ask for
   implementation.

## Comparison Rules

- Keep the content and viewport comparable across options.
- Use real product copy and imagery when they affect the decision.
- Make options legible on a small laptop and responsive below 760 px.
- Label each option by its design idea, not merely A/B/C.
- Keep each screen focused on one question.
- Prefer 2-3 strong options over many weak ones.
- Preserve accessibility fundamentals: readable contrast, visible focus,
  sensible type sizes, and controls that are not color-only.

## Completion Criterion

The run is complete when the user has seen distinct rendered options and either
selected a direction, requested a specific revision, or declined further visual
comparison.
