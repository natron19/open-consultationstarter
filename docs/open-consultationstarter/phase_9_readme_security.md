# Phase 9 — README, Final Cleanup & Security Check

**Builds on:** All prior phases complete. Full RSpec suite passes. App walkthrough works end-to-end.
**Reference docs:** [`docs/prompts/pre-publish-security-check.md`](../prompts/pre-publish-security-check.md) — security prompt to run before publishing to GitHub.
**Goal:** README tells the ConsultationStarter story; the app is clean and portfolio-ready; the security check passes before the repo is made public.

---

## Deliverables

### 1. `README.md` — ConsultationStarter content

Replace or extend the boilerplate README with the following sections. Keep the boilerplate's `Stack`, `License`, `AI Safety Posture`, and `About the Author` sections unchanged.

#### App name and tagline

```
# ConsultationStarter Demo

> Describe the decision. Get a meeting plan that produces a real conversation.
```

#### One-paragraph description

ConsultationStarter Demo turns a one-paragraph description of a decision into a complete meeting plan structured around the Seven Principles of Consultation. Enter your topic, what you are deciding, your participants, and the duration; receive a sharpened purpose statement, three success criteria, anonymous pre-meeting questions, in-session facilitator prompts mapped to the principles, and a decision record template ready to copy into your note-taker.

#### Screenshot

```
![ConsultationStarter Demo screenshot](docs/screenshot.png)
```

Replace `docs/screenshot.png` with a real screenshot of `consultations/show.html.erb` after seeding.

#### Why I built this

I am building ConsultationStarter, a multi-tenant SaaS that gives recurring decision-making bodies — executive teams, boards, committees, councils, faith-community bodies, cooperative circles — a meeting practice grounded in the Seven Principles. The full product has team collaboration, async pre-meeting input, in-session principle checks, longitudinal scorecards across a year of meetings, and a follow-through tracker. This demo strips all of that out and isolates the meeting-plan engine: the moment where a vague topic becomes a structure a group can actually consult inside of.

It is open source under the MIT license because the framework is too valuable to lock behind a single product. If you clone it and use it once a month for the next year, that is a win. If you fork it and extend it for your own context, that is a bigger win.

#### Setup

```bash
git clone <repo>
cd open-consultationstarter
cp .env.example .env
# Add your GEMINI_API_KEY to .env
bin/setup
rails db:seed
bin/dev
```

Sign in at `http://localhost:3000/sign_in` with `demo@example.com` / `password123`.

No app-specific setup beyond the boilerplate's `bin/setup` is required. There is no separate service, no Redis, no background job runner. You need a `GEMINI_API_KEY` from [Google AI Studio](https://aistudio.google.com/app/apikey) and you are ready to run.

#### Editing the AI prompt

The AI template (`consultationstarter_meeting_plan_v1`) is editable in the admin panel at `/admin/ai_templates`. Sign in as the seeded admin, navigate to the template, and use the live test panel on the right to iterate on prompt changes before saving.

#### A note on sensitive data

Do not paste real names, real personnel issues, or real legal matters into this local demo. The decision paragraph and context fields are likely places where users would paste sensitive details. This is a localhost-only demo with no production data handling — treat it accordingly.

---

### 2. Cleanup Checks

Work through each item and tick it off:

- [ ] Open `db/seeds.rb` and confirm any boilerplate placeholder template (e.g. `demo_placeholder_v1`) is removed if it was replaced by the ConsultationStarter template. Both can coexist via `find_or_create_by!` — the important thing is no orphaned placeholder data is seeded.
- [ ] `grep -r "binding.pry\|debugger" app/ spec/ config/` — must return no results.
- [ ] `grep -r "APP_NAME\|APP_TAGLINE\|APP_DESCRIPTION" app/views/` — every instance should use `ENV.fetch`, not a hardcoded string.
- [ ] `grep -rn "ConsultationStarter Demo\|Describe the decision" app/views/` — should return zero results (all reads come from env vars).
- [ ] In the navbar partial, confirm "Consultations" link is inside `<% if signed_in? %>`.
- [ ] In `Admin::BaseController#require_admin`, confirm the response is 404 not 403 (inherited from boilerplate — verify it hasn't been changed).
- [ ] `rails routes` — no duplicate or orphaned routes from development experiments.

---

### 3. Full RSpec Suite

Run the complete test suite one final time before the security check:

```bash
bundle exec rspec
```

Expected: all specs pass, zero failures, zero API calls (confirm by checking that no `LlmRequest` records are created during the test run — or that the count matches only what the specs explicitly test).

---

### 4. Pre-Publish Security Check

**Run this check before making the repository public on GitHub.**

Paste the following prompt into a Claude Code session in this directory:

```
Perform a security review of this Rails app before it's published publicly on GitHub. Check every item below and report findings — safe or risky — with file path and line number for anything flagged.

**1. Hardcoded secrets**
Scan all files for hardcoded API keys, passwords, tokens, or secrets. Check: `.env`, `config/credentials.yml.enc`, `config/master.key`, `config/database.yml`, `config/secrets.yml`, `config/initializers/`, any `.key` files, and any file in `.kamal/`.

**2. Gitignore coverage**
Read `.gitignore` and confirm it excludes:
- `.env` and `.env.*`
- `config/master.key` and all `*.key` files
- `config/credentials.yml.enc`
- `log/` and `tmp/`
Report any of the above that are NOT covered.

**3. `.env.example`**
Read it and confirm every value is a placeholder (e.g. `your_key_here`), not a real value.

**4. `config/database.yml`**
Check for hardcoded username, password, or host. Production values should use `ENV.fetch(...)`.

**5. `db/seeds.rb`**
Check for hardcoded credentials beyond any intentional demo passwords that are documented in the README.

**6. `config/environments/production.rb`**
Check for hardcoded secrets. All sensitive values should use `ENV.fetch(...)`.

**7. Gemfile**
Confirm the only gem source is `https://rubygems.org`. Flag any private gem servers or `git:` sources pointing to private repos.

**8. README**
Check that it doesn't expose internal infrastructure details (internal URLs, server names, real email addresses, internal team names).

**9. Log and tmp files**
Confirm `log/` and `tmp/` contain no tracked files with sensitive content.

**10. Git history**
Run `git log --oneline` and check if any commit message suggests a secret was ever committed (e.g. "add API key", "fix credentials"). If so, flag it — the history would need to be scrubbed before publishing.

For each finding, state: file path, line number (if applicable), what the risk is, and what action to take. Fix any issues you can directly; flag anything that requires a manual step (like rotating a key).
```

Resolve every flagged item before publishing. Common issues to watch for:

- `.env` tracked in git (run `git rm --cached .env` and recommit).
- `config/master.key` tracked in git (same fix; rotate the key after removing it).
- Real values in `.env.example` (replace with `your_value_here` placeholders).
- Hardcoded demo email `demo@example.com` in seeds — this is intentional and documented in the README, so it is safe to flag and accept.

---

## Manual Checks (Final Walkthrough)

Run the full golden path as a new user before publishing:

- [ ] Sign up with a new email address → redirected to dashboard → empty state shows.
- [ ] Click "New Consultation" → form renders with two participant rows.
- [ ] Fill in topic, decision paragraph, duration, add two participants → "Save and Continue".
- [ ] Show page renders with the "Generate Plan" CTA and the seven principles sidebar.
- [ ] Click "Generate Plan" → Turbo Stream updates the plan region without a full page reload.
- [ ] All five plan sections render: purpose statement, success criteria, pre-meeting questions, facilitator prompts, decision record template.
- [ ] AI disclaimer note appears above the facilitator prompts section.
- [ ] Check two principles in the sidebar → hard-refresh → checkboxes remain checked.
- [ ] "Copy to clipboard" button copies the decision record template and briefly shows "Copied!".
- [ ] "Show raw Gemini response" collapse works.
- [ ] "Regenerate Plan" replaces the plan in place.
- [ ] Edit the consultation (change the topic) → "Inputs updated since this plan was generated" notice appears.
- [ ] Delete the consultation → redirected to the index; consultation is gone.
- [ ] Sign in as `demo@example.com` → admin panel → `/admin/llm_requests` shows the LlmRequest log entries from the walkthrough.
- [ ] `/admin/ai_templates` → test panel for `consultationstarter_meeting_plan_v1` generates a plan.

---

## Acceptance Criteria

- [ ] `README.md` updated with ConsultationStarter content (name, tagline, description, why, setup, AI prompt editing note, sensitive data note).
- [ ] All cleanup checks passed (no pry, no hardcoded strings, no orphaned routes).
- [ ] `bundle exec rspec` — full suite green.
- [ ] Security check prompt run and all flagged items resolved.
- [ ] Full end-to-end walkthrough completed by a human.
- [ ] Repository is ready to be made public.
