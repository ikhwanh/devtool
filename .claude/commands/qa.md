Perform end-to-end QA on a web application by logging in and either crawling all reachable pages, focusing on a single page, or walking through a named multi-step flow.

**Arguments**: `$ARGUMENTS` — space-separated tokens:
- `BASE_URL` *(required)* — the root URL of the app (e.g. `https://staging.example.com`)
- `LOGIN_EMAIL` *(optional)*
- `LOGIN_PASSWORD` *(optional)*
- `--page <path>` *(optional)* — focus QA on a single path; skips the crawl
- `--flow <name>` *(optional)* — walk through a named multi-step feature flow; skips the crawl

Examples:
```
/qa https://staging.example.com
/qa https://staging.example.com admin@example.com secret
/qa https://staging.example.com admin@example.com secret --page /dashboard
/qa https://staging.example.com --page /reports/monthly
/qa https://staging.example.com admin@example.com secret --flow onboarding
/qa https://staging.example.com --flow checkout
```

---

## Setup

Parse `$ARGUMENTS`:
- Extract `--page <path>` if present → `FOCUS_PAGE`
- Extract `--flow <name>` if present → `FOCUS_FLOW`
- First remaining token → `BASE_URL`
- Second remaining token (optional) → `LOGIN_EMAIL`
- Third remaining token (optional) → `LOGIN_PASSWORD`

If `LOGIN_EMAIL` or `LOGIN_PASSWORD` are missing, check the environment for `QA_EMAIL` / `QA_PASSWORD` before asking the user.

**Mode selection** (mutually exclusive, checked in order):
1. `FOCUS_FLOW` set → **Flow mode**: skip Steps 2–4, go to Step 2F.
2. `FOCUS_PAGE` set → **Single-page mode**: skip Steps 2 and 4, run Step 3 on that one URL only.
3. Neither set → **Crawl mode**: run all steps.

Open a browser and navigate to `BASE_URL`.

---

## Step 1 — Login

1. Take a screenshot to see the initial state.
2. Look for a login form (email/username + password fields).
3. Fill in credentials and submit.
4. Wait for the post-login redirect to settle.
5. Confirm you are authenticated by checking for user-specific UI (avatar, username, dashboard heading, etc.).
6. If login fails, report the failure immediately and stop.

---

## Step 2 — Discover pages *(crawl mode only)*

Build a list of all pages to visit:

1. **Nav links** — collect every `<a href>` in the top nav, sidebar, and footer that points to the same origin.
2. **In-page links** — after visiting each page, collect new same-origin links (breadth-first, max depth 3).
3. **Visible routes** — check `/sitemap.xml` or `/__routes` if accessible.

Deduplicate. Skip file downloads (`.pdf`, `.zip`, etc.) and external URLs.

---

## Step 2F — Flow execution *(flow mode only)*

A "flow" is a named end-to-end user journey involving multiple steps, interactions, and page transitions.

**Discover the flow entry point:**
- Look for UI that matches `FOCUS_FLOW` by name — e.g. for `onboarding`, look for an "Onboarding", "Get started", or "Setup wizard" link/button/banner.
- If you cannot find a clear entry point, try common paths: `/<flow-name>`, `/setup`, `/wizard`, `/welcome`, `/start`.
- If still not found, report "Flow entry point not found" and stop.

**Walk through every step of the flow:**

For each step, before interacting:
1. Take a screenshot.
2. Collect the current URL, page title, and step indicator (e.g. "Step 2 of 5") if present.
3. Record the **expected outcome** based on what the UI suggests the step does.

Then interact naturally as a user would:
- Fill required fields with realistic placeholder data (names, emails, phone numbers, addresses as appropriate).
- Select options, toggle switches, upload dummy files where needed.
- Click the primary action button (Next / Continue / Submit / Save).
- Wait for the transition to settle (network idle, no spinner).

After each interaction, record:
- **Step name / description** (inferred from heading or label)
- **Action taken**
- **Actual outcome** (URL changed, success message, next step appeared, etc.)
- **Bugs found** (use the same checklist as Step 3)

**Flow-specific checks** in addition to the standard bug checklist:

- **Progress continuity** — verify the step counter or progress bar advances correctly on each step.
- **Back navigation** — if a "Back" or "Previous" button exists, click it on at least one step and verify previously entered data is preserved (not wiped).
- **Skippable steps** — if a step has a "Skip" option, test it; verify the flow still reaches completion and skipped data is absent but not required.
- **Validation on every step** — attempt to proceed with required fields left empty; verify inline validation messages appear and the flow does not advance.
- **Completion state** — confirm the flow reaches a clear success/completion screen (confirmation message, redirect to dashboard, etc.).
- **Post-flow state** — after completion, verify the app reflects the changes (e.g. after onboarding, the user's profile or settings are populated; after checkout, an order appears in order history).
- **Re-entry guard** — navigate back to the flow entry point after completion and verify the app handles it gracefully (redirects away, shows "already completed", or allows editing — whichever is correct — rather than crashing or showing a blank page).

If the flow involves branching paths (e.g. "individual" vs "company" onboarding), test the primary/default branch fully, then note untested branches in the report.

---

## Step 3 — Inspect each page

For every URL in the list (crawl/single-page mode), or for every page reached during the flow (flow mode):

1. Navigate to the page (crawl) or confirm arrival (flow).
2. Wait for network idle and DOM settled.
3. Take a screenshot.
4. Collect browser console messages (errors and warnings).
5. Collect failed network requests (4xx, 5xx).
6. Check for these bug signals:

   **Crashes / blank pages**
   - White screen with no content
   - Unhandled exception banner or error overlay
   - React/Vue/Angular error boundary triggered

   **Broken UI**
   - Overlapping or overflowing elements that obscure content
   - Buttons or links with no visible label
   - Images that failed to load
   - Truncated text that is not intentional

   **Functional errors**
   - Console errors of level `error` (skip third-party ad/analytics noise)
   - Network requests that returned 4xx or 5xx
   - Form submissions that show a raw error message or empty response

   **Data anomalies**
   - Tables or lists that render `null`, `undefined`, `[object Object]`, or `NaN`
   - Empty states where data is expected

   **Auth / permission issues**
   - Unexpected redirect to login
   - 403/401 on pages the user should access
   - Content leaking across roles

   **Calculation errors** — re-derive every visible numeric value from visible source data:
   - **Totals / subtotals**: re-sum all line items; flag mismatches.
   - **Percentages**: recompute `part / whole × 100`; flag percentage-vs-decimal mistakes.
   - **Averages, discounts, fees, taxes**: recompute from stated rate and base amount.
   - **Running balances**: verify each row follows from the previous row plus current value.
   - **Rounding**: flag inconsistent rounding modes.
   - **Currency / unit consistency**: flag mixed currencies or units without conversion.
   - **NaN / Infinity**: flag any degenerate computed value.
   - Server-derived totals: mark as "server-derived — not verified".

Record each bug immediately as it is found.

---

## Step 4 — Interactive spot-checks *(crawl mode only)*

On a sample of pages (up to 5, prioritise forms and modals):

1. Open any modal or dialog — check it renders and can be closed.
2. Submit an empty form — verify validation messages appear.
3. If there is a search input, type a query and check results render without errors.

---

## Step 5 — Report

Print a structured bug report:

```
# QA Report — <BASE_URL>
Date: <today>
Mode: <Crawl | Single-page: /path | Flow: "flow-name">
Pages / steps covered: <count>

## Critical bugs (crashes, auth failures, data loss risk)
- [PAGE URL | Step name] <description> — <evidence>

## Major bugs (broken UI, failed requests, missing data, calculation errors, flow breakage)
- [PAGE URL | Step name] <description> — <evidence: expected `X`, got `Y`>

## Minor bugs (cosmetic issues, non-blocking warnings)
- [PAGE URL | Step name] <description> — <evidence>

## Flow summary *(flow mode only)*
- Steps completed: <list>
- Untested branches: <list or "none">
- Post-flow state verified: yes / no / partial

## Clean pages
<comma-separated list of URLs / steps with no issues found>

## Skipped / unreachable
<URLs or steps that timed out, errored before loading, or could not be reached>
```

If no bugs are found on a page or step, list it under "Clean pages" only.
After the report, close the browser.
