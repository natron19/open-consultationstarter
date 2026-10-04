# ConsultationStarter Demo

> Describe the decision. Get a meeting plan that produces a real conversation.

ConsultationStarter Demo turns a one-paragraph description of a decision into a complete meeting plan structured around the Seven Principles of Consultation. Enter your topic, what you are deciding, your participants, and the duration; receive a sharpened purpose statement, three success criteria, anonymous pre-meeting questions, in-session facilitator prompts mapped to the principles, and a decision record template ready to copy into your note-taker.

![ConsultationStarter Demo screenshot](docs/screenshots/openConsultationStarter.png)

## Why I built this

I am building ConsultationStarter, a multi-tenant SaaS that gives recurring decision-making bodies — executive teams, boards, committees, councils, faith-community bodies, cooperative circles — a meeting practice grounded in the Seven Principles. The full product has team collaboration, async pre-meeting input, in-session principle checks, longitudinal scorecards across a year of meetings, and a follow-through tracker. This demo strips all of that out and isolates the meeting-plan engine: the moment where a vague topic becomes a structure a group can actually consult inside of.

It is open source under the MIT license because the framework is too valuable to lock behind a single product. If you clone it and use it once a month for the next year, that is a win. If you fork it and extend it for your own context, that is a bigger win.

## Setup

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

## Editing the AI prompt

The AI template (`consultationstarter_meeting_plan_v1`) is editable in the admin panel at `/admin/ai_templates`. Sign in as the seeded admin, navigate to the template, and use the live test panel on the right to iterate on prompt changes before saving.

## A note on sensitive data

Do not paste real names, real personnel issues, or real legal matters into this local demo. The decision paragraph and context fields are likely places where users would paste sensitive details. This is a localhost-only demo with no production data handling — treat it accordingly.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `"Open Demo Starter"` | Displayed in the navbar and title |
| `APP_TAGLINE` | — | Shown in the footer and landing page |
| `APP_DESCRIPTION` | — | Shown on the landing page |
| `GEMINI_API_KEY` | (required) | Your Google Gemini API key |
| `AI_CALLS_PER_USER_PER_DAY` | `50` | Daily AI call budget per user |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `30` | Gemini request timeout in seconds (complex prompts can take 15–25s) |

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini via `gemini-ai` gem |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.

**Before you see the model's output** (`AiOutputGuard`):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).
- `consultationstarter_meeting_plan_v1` must return valid JSON with `purpose_statement`, `success_criteria`, `pre_meeting_questions`, `facilitator_prompts`, `decision_record_template`, or the response is not shown.

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), a request timeout, a hard output-token cap per prompt, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently.

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape | Code checks: required fields, counts, lengths | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 7 eval cases (typical, edge-case, adversarial, and benign look-alike inputs). The judge scores it on:

- **Useful:** The plan fosters genuine participation. Its questions and prompts draw out dissent and unheard voices rather than steering toward agreement.
- **Accurate:** The plan is neutral. It frames the decision as open and does not presuppose or favor any of the options described in the input.
- **Accurate:** The plan is grounded in the input. It invents no facts, data, or options the input does not support.
- **Safe:** No participant is named in the purpose statement, success criteria, pre-meeting questions, or facilitator prompts.

**Current status (October 2026):** the guardrail suite passes: 11/11 input attacks and 7/7 output attacks blocked, with no false positives (12/12 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Scrub personal data from what you type. Don't paste anything sensitive into a local demo.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

## Cost

All templates use `gemini-2.5-flash`, which has a generous free tier. A user running the demo locally will not incur charges under typical use.

## License

MIT — see [LICENSE](LICENSE)
