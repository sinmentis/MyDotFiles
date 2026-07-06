---
name: entry-dca-team
description: Use when deciding when to invest a lump sum of cash and how to split the purchase into tranches (dollar-cost averaging) — e.g. "I have $X, when should I buy the S&P 500 and how should I phase it in?"
---

# Entry Timing & Phased Position Building (Entry-DCA) Team

## Overview

Turns a lump-sum entry decision into a concrete plan: an equity vs.
cash/short-duration-bond split, a tranche schedule, and rules for
accelerating or pausing that schedule. Four independent research roles run
in parallel (macro cycle, valuation/timing, FX + local tax/ops, and an
independent risk review), then get synthesized — modeled on a small
investment committee, not a single analyst.

**Core principle:** risk tolerance (how much volatility you can stomach)
and liquidity rigidity (whether this money has a hard deadline) are two
different axes. Conflating them is the most common failure mode here — see
Common Mistakes.

This is a research/planning framework, not investment advice — the user
makes the final call.

## When to Use

- User has a lump sum and asks "when should I invest this" or "how do I
  dollar-cost-average into X"
- Deploying money that just became available (inheritance, bonus, sale
  proceeds, RSU vest) into a broad index/ETF
- Building or revisiting a phased entry plan for an existing undeployed
  cash position

Not for picking individual stocks, or rebalancing an already fully
invested portfolio.

## Required Inputs

Ask for anything missing before starting. Never assume the two starred
items — get them from the user, since they determine the equity/cash
split:

| Field | Example |
|---|---|
| Target asset/market | S&P 500, Nasdaq 100, a global equity index fund |
| Tax residency / jurisdiction | New Zealand tax resident |
| Investable amount + currency | NZD 200,000 |
| Share of investable assets | ~35% |
| Holding period | 1-2 years |
| **Liquidity rigidity**\* | Fully discretionary cash vs. must be cashed out by a fixed date |
| **Risk tolerance ceiling**\* | e.g. "can tolerate S&P 500-level volatility" |

\* Guessing wrong here invalidates the whole plan.

## The Four Roles

| Role | Researches | Produces |
|---|---|---|
| **Coordinator (you)** | Synthesizes, resolves conflicts between roles | Final entry + tranche plan |
| **Macro analyst** | Central bank policy/rates, inflation, employment, recession indicators (Sahm Rule, yield curve, LEI), geopolitical risk, VIX, upcoming calendar events | A "macro cycle stage" call |
| **Valuation/timing strategist** | Index level vs. all-time high, trailing/forward P/E, Shiller CAPE vs. history, market breadth & top-10 concentration, sell-side 12-24m targets, historical forward-return distribution at similar valuations | A "valuation regime" call |
| **FX / local-ops specialist** | Home currency vs. USD outlook (with confidence caveat), hedging cost direction, local tax treatment of foreign holdings, local fund vs. direct ETF (tax/estate implications), suitable platforms | FX & implementation guidance |
| **Risk reviewer** | Independently reviews the other three; pokes holes, doesn't rewrite | A risk critique |

**Run the risk reviewer on a different model (family) than the other
three** — if the others use one vendor's model, switch it. That makes the
review a genuine second opinion instead of a model checking its own work.

## Process

1. **Anchor the date.** Confirm today's actual date (e.g. run `date`)
   before researching anything — training data is likely stale. Every
   time-sensitive claim (rates, index levels, VIX, recession indicators)
   must be verified via web search and cited with source + publish date.
   State the data-cutoff date at the top of the final report.
2. **Confirm inputs.** Stop and ask if liquidity rigidity or risk
   tolerance is missing; don't guess.
3. **Launch the four roles in parallel**, one background sub-agent per
   role, in a single dispatch. Roles don't share context, so each brief
   must be self-contained. Give each role its research points from the
   table above, plus this shared method:
   - Confirm the date first; don't rely on training-data numbers for
     anything time-sensitive.
   - Cite a source (organization/site) and publish date for every factual
     claim.
   - Mark unverifiable numbers explicitly ("could not verify, rough
     estimate") — never invent figures.
   - Reach an explicit conclusion; don't hedge into "it depends."

   The risk reviewer's brief must additionally require explicit yes/no
   answers on whether the other three:
   - Mix long-horizon statistics (e.g. 10-year CAGR distributions) with
     short-horizon conclusions (what to do within a 1-2 year hold)
   - Derive hedge direction from the interest-rate differential between
     the two currencies (correct) rather than from whether the currency
     looks historically high/low (wrong)
   - Conflate risk tolerance (can stomach volatility) with liquidity
     rigidity (must cash out by a deadline)

   Launch the risk reviewer once the other three results are back — it
   needs their actual content to critique.
4. **Collect all four results** before synthesizing.
5. **Synthesize the final guide** (below) — not a copy-paste of the four
   reports.
6. **Save the report** somewhere the user can find again (ask where, or
   default to the current directory), with the data-cutoff date at the
   top.

## Output Requirements

All five sections are required:

1. **Risk tolerance vs. liquidity rigidity check**, first, using this
   grid:

   |  | High volatility tolerance | Low volatility tolerance |
   |---|---|---|
   | **Low rigidity (discretionary cash)** | Normal allocation, normal pace | Conservative allocation, normal pace |
   | **High rigidity (hard deadline)** | Still reduce allocation — the deadline picks the exit price, not you | Conservative allocation, conservative pace |

   State which quadrant applies. If the risk reviewer flags the two as
   conflated, fix it here by **resizing the equity allocation, not just
   the tranche pace** — pace only affects average entry price; allocation
   size determines whether the position survives an unfavorable price at
   the deadline.

2. **Equity vs. cash/short-duration-bond split.** Combine the macro-cycle
   call, valuation-regime call, and rigidity quadrant into an explicit
   range (e.g. "70-85% equity, 15-30% cash/short bonds") with the
   reasoning spelled out.

3. **Tranche schedule.** Number of tranches, rough share in each, and the
   time interval or catalyst that triggers the next one. More/longer-
   spaced tranches when valuation looks stretched; fewer/faster when it
   looks reasonable or cheap.

4. **Accelerate/pause rules**, gated on **both** price **and**
   fundamentals/volatility — a price-only rule is incomplete. Cover at
   least:
   - Accelerate: price down X%, VIX/recession indicators not deteriorating
     → pull the next tranche forward
   - Proceed as planned: price moved either way, macro unchanged → don't
     skip a tranche just because price ran up
   - Pause and reassess: price down X%, but VIX spiked / credit spreads
     widened / recession indicators worsened → don't mechanically average
     down
   - Pause and reassess: macro-cycle call deteriorates materially (e.g.
     Sahm Rule triggers), regardless of price → resize the target
     allocation, not just the pace

5. **Consensus and disagreement.** What the roles agree on, where they
   disagree and how it was resolved, and an explicit accept/reject note
   for every issue the risk reviewer raised.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Treating "can tolerate volatility" and "must cash out on schedule" as the same thing | They're independent axes; a conflict means resizing the equity allocation, not slowing the tranche pace |
| Using a 10-year forward-return distribution (e.g. from CAPE) to justify a 1-2 year decision | Valuation metrics like CAPE explain ~10-year returns reasonably well and 1-2 year returns barely at all — label the horizon and never mix the two |
| Deciding hedge direction from whether FX "looks high or low" historically | Hedging cost direction comes from the interest-rate differential between the two currencies, not the FX level |
| An accelerate/pause rule that only checks price | Always gate on price **and** fundamentals/volatility together |
| Citing macro/valuation/FX numbers from memory | Training data goes stale; verify time-sensitive figures via web search and cite source + date |
| Letting the risk reviewer use the same model as the other roles | Use a different model (family) so the review is a genuine second opinion |
