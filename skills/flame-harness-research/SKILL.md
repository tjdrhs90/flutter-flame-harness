---
name: flame-harness-research
description: Phase 1 — discover Flame game concepts from store charts/competitors, propose 2-3 options, query the user, and record the chosen concept.
argument-hint: ""
allowed-tools: [Agent, Read, Write, Edit, WebFetch, WebSearch, AskUserQuestion, Bash]
---

# flame-harness-research

Phase 1 of the flutter-flame-harness pipeline. Reads the user's raw idea from `config.md`, performs
market research if needed, proposes 2-3 concrete game concepts, queries the user via AskUserQuestion
to pick one, checks it for App Store guideline 4.3 clone risk, then writes the research spec and
advances the pipeline state.

All file schemas (`config.md`, `state.md`, `pipeline-log.md`) are defined in
`docs/harness-protocol.md` — refer to that document as the single source of truth. Do not redefine
schemas here.

---

## Input

Read `docs/harness/config.md` and extract:

- `app_idea` — the raw one-line game idea supplied by the user (may be blank if the user invoked
  the harness without an idea, in which case you will generate ideas from scratch in the Discovery
  step). When `app_idea` is blank, the Discovery and "Propose & query" steps run exactly as normal
  but driven purely by market research and creative reasoning with no seed concept; the resulting
  proposals are still presented via AskUserQuestion for the user to pick — the AI never selects
  automatically.
- `skip_research` — boolean. If `true`, treat `app_idea` as the chosen concept verbatim and
  **skip the Discovery and "Propose & query" steps entirely**. Jump directly to Clone avoidance,
  then Output. Even when skipping discovery you must still write the research spec.

If `config.md` does not exist, abort with:
`flame-harness-research: docs/harness/config.md not found — run the orchestrator to bootstrap first.`

---

## Discovery

> Skip this section when `skip_research: true`.

Goal: understand the current mobile game landscape so the proposals are grounded in real market data.

### 1. Top-charting games

Use WebSearch and/or WebFetch to fetch the current top-grossing and top-free charts for mobile games
on Google Play and the App Store. Search queries to use:

- `"Google Play" top grossing mobile games 2026 site:sensor tower OR site:appfigures OR site:apptopia`
- `"App Store" top free games 2026 site:sensor tower OR site:apptopia`
- `"Flutter Flame" game examples 2026`

For each chart, extract at least 10 titles and their genre/mechanic (e.g. idle clicker, hyper-casual
runner, match-3, tower defense, merge).

### 2. Competitor mapping

For the genre most aligned with `app_idea` (if provided), or the top 2 genres by chart frequency,
fetch the store pages of 3-5 representative titles via WebFetch. Record for each:

- Title, genre, core mechanic
- Differentiating feature (what makes it stand out)
- Approximate rating and download tier (if visible on the page)

### 3. Trend signals

Use WebSearch to look for "hypercasual game trends 2026" and "mobile game genre growth 2026".
Extract 2-3 specific trend signals (e.g. "merge mechanics growing 40% YoY", "offline-playable
games rising") to inform your proposals.

---

## Propose & query

Synthesise your Discovery findings (and `app_idea` if provided) into exactly **2-3 concrete game
concept proposals**. Each proposal must include:

| Field | Description |
|---|---|
| Title | Working title |
| Tagline | One sentence (≤ 15 words) describing the core loop |
| Core mechanic | What the player does every 10–30 seconds |
| Differentiator | One thing that makes it distinct from existing top charts |
| Flame suitability | Why Flutter/Flame is a good fit (≤ 2 sentences) |
| Monetisation hook | How AdMob ads fit naturally (interstitial / rewarded / banner) |

Present the proposals in a numbered list that is easy to read.

Then use **AskUserQuestion** to ask the user to pick one or refine:

```
Which concept would you like to build?
Reply with the number (1, 2, or 3), or describe a variation.
If you are happy with one as-is, just type its number.
```

Wait for the user's response. If the user types a number, set the chosen concept to that proposal.
If the user describes a variation, merge their input with the closest base proposal and confirm
the merged concept with a follow-up AskUserQuestion before proceeding:

```
Got it. I'll build: <merged concept summary>.
Is this correct? (yes / describe further)
```

Repeat until the user confirms.

---

## Clone avoidance

App Store guideline **4.3** prohibits apps that are copies of existing apps ("clone avoidance").
Before writing the spec, verify the chosen concept does not constitute a direct clone.

### Check procedure

1. Extract the core mechanic from the chosen concept.
2. Use WebSearch to find the 3 most similar existing mobile games:
   `"<core mechanic>" mobile game App Store 2025 OR 2026`
3. For each similar game, note: title, mechanic, distinctive features.
4. Apply the clone test: a concept is a **clone** if it shares the same mechanic AND the same
   theme/setting AND offers no original feature. A concept is **safe** if it has at least one of:
   - A novel mechanic twist (e.g. gravity inversion in a runner)
   - A distinct setting/art direction not present in the top-3 matches
   - A gameplay mode absent from the top-3 matches (e.g. co-op, asynchronous multiplayer)

5. If the concept is a clone, do not proceed. Use AskUserQuestion to ask:
   ```
   The chosen concept is too similar to <similar app> on the App Store, which may violate
   App Store guideline 4.3 (clone rule).
   Please describe how you want to differentiate it, or pick a different concept.
   ```
   Then re-run the clone check on the revised concept.

6. Record the clone-check result in the research spec (see Output).

---

## Output

### 1. Write the research spec

Create `docs/harness/specs/<YYYY-MM-DD>-research.md` (use today's UTC date). Use the following
structure:

```markdown
# Research Spec — <app_name>

## Chosen Concept

**Title:** <working title>
**Tagline:** <one sentence>
**Core mechanic:** <what the player does>
**Differentiator:** <unique hook>
**Flame suitability:** <why Flutter/Flame fits>
**Monetisation hook:** <AdMob integration point>

## Market Rationale

<2-4 sentences summarising the chart/trend data that supports this choice.
Reference the top competitors and the trend signals discovered.>

## Competitor Summary

| Title | Mechanic | Differentiator |
|---|---|---|
| <title> | <mechanic> | <differentiator> |

## Clone-Avoidance Check (App Store 4.3)

**Result:** SAFE / CLONE (resolved)
**Similar apps checked:** <title 1>, <title 2>, <title 3>
**Differentiating features:** <list the features that prevent a 4.3 rejection>

## Skip-Research Note

<!-- If skip_research was true, write: "Discovery skipped — app_idea accepted verbatim." -->
<!-- Otherwise delete this section. -->
```

### 2. Update `config.md`

Set `app_idea` to the final confirmed concept tagline (overwrite the original raw idea). This
ensures downstream skills (plan, design, contract) read the refined concept, not the raw prompt.

Use `Edit` to make a targeted update — do not rewrite the entire file.

### 3. Update `state.md`

Update `docs/harness/state.md` per the schema in `docs/harness-protocol.md` §2:

```yaml
status: running
current_phase: research
next_role: plan
updated_at: "<ISO-8601 UTC now>"
```

Leave all other keys unchanged. Use `Edit` for a targeted update.

### 4. Append to `pipeline-log.md`

Append one row to `docs/harness/pipeline-log.md` per the schema in `docs/harness-protocol.md` §6:

```
| <ISO-8601 UTC now> | complete | research | <N> competitors analysed; concept: <working title> |
```

If `skip_research` was true, use:

```
| <ISO-8601 UTC now> | complete | research | skip_research=true; concept accepted verbatim |
```

---

## Error handling

- If WebSearch or WebFetch fails during Discovery, log a warning and proceed with whatever data
  was retrieved. Do not abort — partial market data is better than none.
- If the user declines all proposals and provides no viable alternative after 3 rounds of
  AskUserQuestion, set `state.md` to `status: paused`, `pause_reason: manual_action`, and write
  a note to `pipeline-log.md` explaining that the user could not settle on a concept.
- If `docs/harness/specs/` does not exist, create it before writing the spec file.
