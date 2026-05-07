# ConsultationStarter Demo - Specification

**Document Version:** 1.0
**Last Updated:** May 2026
**Built On:** Open Demo Starter v2.0
**License:** MIT
**Source Brief:** 35_AppBrief_ConsultationStarter_v1.md
**Production PRD:** 35_ConsultationStarter_PRD_v2.md
**Accent Color:** `#0c4a6e` (deep ocean blue)
**UX Pattern:** Pre-meeting brief with persistent seven-principle checklist sidebar

---

## 1. App Overview

ConsultationStarter Demo is a small, locally-runnable Rails 8 app that turns a one-paragraph description of a decision into a complete Consultation Plan structured around the Seven Principles of Consultation. The user enters the meeting topic, what is being decided, the participants, the duration, and any sensitivities. Gemini returns five tightly-structured artifacts: a sharpened purpose statement, three success criteria, three to five anonymous pre-meeting questions, five facilitator prompts mapped to the principles, and a decision record template for the note-taker.

Most meetings are unstructured opinion-trading. They produce decisions that no one is committed to implementing, dissent that goes on the record only after the fact, and follow-through that quietly drops to half. The Seven Principles (Spirit of Service, Unity of Purpose, Detachment, Frankness with Courtesy, Equality of Voice, Search for Truth, Unity in Action) are centuries of practitioner wisdom encoded into a workable meeting discipline. This demo isolates the meeting-plan engine that sits at the core of the larger ConsultationStarter product: the moment where a vague topic becomes a structure a group can actually consult inside of.

The production version of ConsultationStarter is a multi-tenant SaaS with team collaboration, async pre-meeting input collection, live in-session principle checks, longitudinal seven-principle scorecards across a year of meetings, and a follow-through tracker. This demo deliberately strips all of that out. It is open source under the MIT license, scoped to a single signed-in user, and runs on localhost. The point is to show the prompt design and the principle-encoded output structure, nothing more.

This is one of twenty-two single-purpose AI demo apps in the author's GitHub portfolio. Each demo isolates the most valuable thing a user can do in one tool from a larger SaaS suite. All demos are built on the same Open Demo Starter boilerplate, so the auth, layout, Gemini service, request log, gatekeeper, budget cap, and admin panel are inherited and identical across the portfolio. What changes per demo is the domain model, the AI template, the views, the accent color, and the UX pattern.

---

## 2. Customizations Applied to the Boilerplate

| Customization | Value |
|---|---|
| `APP_NAME` (in `.env.example`) | `ConsultationStarter Demo` |
| `APP_TAGLINE` | `Describe the decision. Get a meeting plan that produces a real conversation.` |
| `APP_DESCRIPTION` | `An AI-powered meeting planner that organizes any decision-making meeting around the Seven Principles of Consultation. Enter the topic, the decision paragraph, the participants, and the duration. Get back a sharpened purpose statement, success criteria, anonymous pre-meeting questions, in-session facilitator prompts, and a decision record template.` |
| Accent color in `_accent.scss` | `--accent: #0c4a6e; --accent-hover: #075985;` |
| Navbar link added | `Consultations` (links to `/consultations`) |
| Home page | `home/index.html.erb` replaced with the consultation pitch and a "Plan Your Next Decision" CTA |
| Dashboard page | `dashboard/show.html.erb` replaced with the user's recent consultations card-grid plus a "New Consultation" button |
| UX pattern | Form-then-result, with a persistent right sidebar listing the seven principles as a checklist (visible on the consultation show page; sticky during scroll) |
| AI templates seeded | `consultationstarter_meeting_plan_v1` (full content in Section 7) |

No new gems, no background jobs, no Active Storage, no JavaScript bundlers. Stimulus and Turbo only.

---

## 3. Data Model

Three new domain models on top of `User`, `AiTemplate`, and `LlmRequest` (all of which are inherited from the boilerplate and not redescribed here).

### Consultation

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `user_id` | uuid | FK to `users` |
| `topic` | string | The meeting topic in one sentence. **(template variable)** |
| `decision_paragraph` | text | One paragraph describing what is actually being decided. **(template variable)** |
| `duration_minutes` | integer | Meeting length in minutes. **(template variable)** |
| `context` | text | Optional. Recent history, prior attempts, sensitivities. **(template variable)** |
| `scheduled_for` | datetime | Optional. When the meeting is planned. |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations**
- `belongs_to :user`
- `has_many :participants, dependent: :destroy`
- `has_one :consultation_plan, dependent: :destroy`
- `accepts_nested_attributes_for :participants, allow_destroy: true, reject_if: :all_blank`

**Validations**
- `topic` presence, length 5 to 200
- `decision_paragraph` presence, length 20 to 2000
- `duration_minutes` presence, integer, 5 to 240
- `context` length up to 2000 (optional)
- At least one associated `Participant` on save (custom validation)

### Participant

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `consultation_id` | uuid | FK to `consultations` |
| `name` | string | First name or pseudonym; the demo does not collect last names or emails. |
| `role` | string | What this person represents in the room (e.g., "Engineering Lead", "Board Member", "Customer Voice"). |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations**
- `belongs_to :consultation`

**Validations**
- `name` presence, length 1 to 80
- `role` presence, length 1 to 80

Participants are rendered into the prompt as a single newline-delimited list passed in as the `{{participants_list}}` template variable. They are not persisted on Gemini's side and never appear in pre-meeting questions or facilitator prompts; they appear only in the decision record template's "Unity-in-Action Commitments" section.

### ConsultationPlan

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `consultation_id` | uuid | FK to `consultations`, unique |
| `purpose_statement` | text | One sentence, decision-shaped reformulation of the topic. |
| `success_criteria` | text | JSON array of three specific markers. Stored as serialized JSON. |
| `pre_meeting_questions` | text | JSON array of question objects (`{question, principle}`). |
| `facilitator_prompts` | text | JSON array of five prompt objects (`{order, principle, prompt, when_to_use}`). |
| `decision_record_template` | text | Markdown-formatted template for the meeting note-taker. |
| `gemini_raw` | text | **(Gemini output, used for Show raw response toggle)** Full JSON string returned by Gemini. |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**Associations**
- `belongs_to :consultation`
- `has_one :user, through: :consultation`

**Validations**
- All five structured fields present on save
- `gemini_raw` presence
- One plan per consultation enforced via unique index on `consultation_id`

The text columns hold serialized JSON for the array-shaped fields. The model exposes `success_criteria_array`, `pre_meeting_questions_array`, and `facilitator_prompts_array` reader methods that parse the JSON for view consumption. If parsing fails, the views fall back to rendering `gemini_raw` directly via the "Show raw response" toggle.

---

## 4. Routes

| Verb | Path | Controller#Action | Purpose |
|---|---|---|---|
| GET | `/` | `home#index` | Landing pitch, replaces boilerplate home |
| GET | `/dashboard` | `dashboard#show` | User's recent consultations grid |
| GET | `/consultations` | `consultations#index` | List user's consultations |
| GET | `/consultations/new` | `consultations#new` | Form for a new consultation |
| POST | `/consultations` | `consultations#create` | Create consultation with nested participants |
| GET | `/consultations/:id` | `consultations#show` | Consultation one-pager with plan (or generate button) |
| GET | `/consultations/:id/edit` | `consultations#edit` | Edit form |
| PATCH | `/consultations/:id` | `consultations#update` | Update consultation and participants |
| DELETE | `/consultations/:id` | `consultations#destroy` | Delete consultation and its plan |
| POST | `/consultations/:id/plan` | `consultation_plans#create` | Generate or regenerate the plan via Gemini |
| DELETE | `/consultations/:id/plan` | `consultation_plans#destroy` | Discard the existing plan |

All HTML responses. No JSON API routes. The plan-generate action returns a Turbo Stream that swaps the plan region of the show page in place; non-Turbo clients get a redirect to the show page.

Auth routes (`/sign_up`, `/sign_in`, `/passwords/*`) and admin routes (`/admin/*`) are inherited from the boilerplate.

---

## 5. Controllers and Actions

### `ConsultationsController`

Standard RESTful resource controller scoped to `current_user`.

- `index`: Lists `current_user.consultations.order(created_at: :desc)`. Renders a card grid; each card shows topic, scheduled-for date, participant count, and a status badge (`Plan generated` or `Awaiting plan`).
- `new`: Builds an empty `Consultation` with two empty `Participant` children pre-built so the nested form has rows visible by default.
- `create`: Builds the consultation via `current_user.consultations.build(consultation_params)` and saves. On success, redirects to the show page (where the user can then click "Generate Plan"). On failure, re-renders the form with errors.
- `show`: Loads the consultation and its plan if present. Renders the one-pager view. If no plan exists, renders the "Generate Plan" CTA in place of the plan region.
- `edit`: Standard edit form. Existing participants are rendered as removable nested rows.
- `update`: Updates the consultation and its nested participants. If the plan exists and the user has materially changed the inputs, the show page surfaces a "Plan may be stale; regenerate?" notice.
- `destroy`: Deletes the consultation and (via `dependent: :destroy`) its participants and plan.

Strong params: `consultation_params` permits `:topic, :decision_paragraph, :duration_minutes, :context, :scheduled_for, participants_attributes: [:id, :name, :role, :_destroy]`.

### `ConsultationPlansController`

Two actions: `create` (generate or regenerate) and `destroy` (discard).

- `create`: This is the action that triggers the Gemini call. It loads the consultation (`current_user.consultations.find(params[:consultation_id])`), builds the variables hash from the consultation and its participants, and calls:

  ```ruby
  result = GeminiService.generate(
    template: "consultationstarter_meeting_plan_v1",
    variables: {
      topic: @consultation.topic,
      decision_paragraph: @consultation.decision_paragraph,
      duration_minutes: @consultation.duration_minutes,
      context: @consultation.context.presence || "(none provided)",
      participants_list: @consultation.participants.map { |p| "- #{p.name} (#{p.role})" }.join("\n")
    }
  )
  ```

  Parses the returned JSON, builds or replaces the `ConsultationPlan` record, stores `gemini_raw` for the toggle, and responds with a Turbo Stream that replaces the `#plan-region` frame on the show page. The save is wrapped in a single transaction so a parse failure leaves the prior plan intact.

- `destroy`: Deletes the plan. Used when the user wants to discard a generated plan and start over without re-running Gemini.

The controller catches `GeminiService::GeminiError` and its subclasses (`BudgetExceededError`, `GatekeeperError`, `TimeoutError`) and renders the boilerplate's `shared/_gemini_error` partial with a retry button. Specific subclasses get specific copy: budget messages explain the daily cap, gatekeeper messages explain that the input contained patterns the gatekeeper flags, and timeout messages explain the 15-second cap and offer retry.

Strong params: none beyond the consultation ID, which is route-scoped.

---

## 6. Views

### `home/index.html.erb` (replaces boilerplate)

Single-screen landing pitch. Above the fold: tagline, one-paragraph description, a primary CTA button (`Plan Your Next Decision`) styled with `var(--accent)`. Below: a three-column features row describing the five plan elements (purpose, success criteria, pre-meeting questions, facilitator prompts, decision record). Footer is the boilerplate footer with the AI disclaimer.

### `dashboard/show.html.erb` (replaces boilerplate)

Grid of the user's most recent consultations (Bootstrap card grid, three columns on desktop). Each card shows topic, scheduled-for date, participant count, and a status badge. Empty state: a single centered card with the consultation pitch and a `New Consultation` button.

### `consultations/index.html.erb`

Same card grid as the dashboard, but unbounded (paginated only if needed; v1 is single-user so no pagination expected). Sort dropdown: `Most recent`, `Scheduled soonest`.

### `consultations/_form.html.erb`

Used by `new` and `edit`. Sections in vertical order:
- Topic input (single-line, required)
- Decision paragraph (multi-line, 4 rows, required)
- Duration in minutes (number input, required, defaults to 60)
- Scheduled for (datetime-local, optional)
- Context (multi-line, 3 rows, optional, with placeholder text suggesting recent history and sensitivities)
- Participants (nested fields with `Add Participant` button driven by a Stimulus controller; each row has Name, Role, and a Remove button; minimum one row enforced client-side and server-side)

The submit button reads `Save and Continue` on `new` and `Update Consultation` on `edit`.

### `consultations/_participant_fields.html.erb`

Stimulus template fragment. The Stimulus controller (`participants_controller.js`) clones the template on `Add Participant` click and replaces the placeholder index with a unique value so Rails treats each as a new nested record.

### `consultations/show.html.erb`

The printable one-pager. Layout: main column (about 70% width on desktop) plus persistent right sidebar (about 30%, sticky during scroll, collapses to a bottom sheet on mobile).

Main column structure:

1. **Header.** Topic in large display type. Below: scheduled-for date, duration, participant count.
2. **Purpose statement card.** When the plan exists, the sharpened purpose statement is rendered in large type at the top of the card. When the plan does not yet exist, this card is replaced with a "Generate Plan" call-to-action that POSTs to `/consultations/:id/plan`.
3. **Success criteria card.** Three numbered items.
4. **Pre-meeting questions card.** Each question rendered as a row with the question text and a small principle badge styled with `var(--accent)`.
5. **Facilitator prompts list.** Numbered list (5 items). Each item shows: prompt text in primary type, principle badge, and a one-sentence "when to use" line in muted text.
6. **Decision record template card.** Markdown-rendered template ready to copy into the meeting note-taker's tool of choice. Includes a `Copy to clipboard` button (Stimulus).
7. **Plan footer.** Contains the `Show raw response` toggle (Bootstrap collapse) revealing `gemini_raw`, plus a `Regenerate Plan` button that re-runs the Gemini call.

The main plan region (items 2 through 7) is wrapped in a Turbo Frame (`id="plan-region"`) so the generate action can swap it in place.

### `shared/_seven_principles_sidebar.html.erb`

The persistent right sidebar. A vertically-stacked card listing all seven principles as a checklist. Each row: principle name, one-sentence description, and a checkbox the facilitator can tick during the meeting (state stored in localStorage scoped to the consultation ID; cleared on plan regeneration). The header reads "Use during the meeting" and a small note explains that ticks are local to the browser only. This sidebar is rendered on `consultations/show` and `consultations/edit` only.

### `consultations/_consultation_card.html.erb`

Shared partial used by `dashboard/show` and `consultations/index`. Renders one consultation as a Bootstrap card with topic, scheduled-for, participant count, and status badge. Click target is the show page.

### `consultation_plans/_plan.html.erb`

The plan partial extracted from `consultations/show.html.erb` so the Turbo Stream from `ConsultationPlansController#create` can replace just the plan region. Rendered inside the `plan-region` Turbo Frame on the show page.

### `shared/_gemini_error.html.erb`

Inherited from the boilerplate; used as-is. Different `GeminiError` subclasses pass different copy strings.

---

## 7. AI Templates and Gemini Integration

This demo seeds one AiTemplate. The boilerplate's `GeminiService` looks it up by name; the controller never constructs a prompt inline.

### Template `consultationstarter_meeting_plan_v1`

**`description`**: Generates a complete five-part Consultation Plan from a meeting brief, with each part mapped to one or more of the Seven Principles of Consultation.

**`system_prompt`**:

```
You are a consultation facilitator trained in the Seven Principles of Consultation:

1. Spirit of Service and Adding Value: each participant enters the meeting to advance the collective purpose rather than advance their own position.
2. Unity of Purpose: the meeting question is explicit, shared, and revisited when discussion drifts.
3. Detachment from Personal Views: ideas are evaluated on merit, not on who proposed them.
4. Frankness with Courtesy: dissent is welcomed and explored; honesty is delivered in a way that makes it easier for others to be honest in turn.
5. Equality of Voice: every participant with relevant perspective has meaningful opportunity to shape the outcome.
6. Search for Truth: decisions are based on evidence, including evidence that contradicts what the group would prefer to believe.
7. Unity in Action: after the decision, the group implements together regardless of which position each person held during deliberation.

Your job is to take a description of an upcoming decision-making meeting and produce a complete Consultation Plan in five sections. Each section maps explicitly to one or more of the Seven Principles. You may not omit a section. You may not omit a principle from the facilitator prompts.

Output a single JSON object with exactly this schema:

{
  "purpose_statement": "string, one sentence",
  "success_criteria": ["string", "string", "string"],
  "pre_meeting_questions": [
    {"question": "string", "principle": "string"}
  ],
  "facilitator_prompts": [
    {"order": 1, "principle": "Spirit of Service", "prompt": "string", "when_to_use": "string"},
    {"order": 2, "principle": "Equality of Voice", "prompt": "string", "when_to_use": "string"},
    {"order": 3, "principle": "Frankness with Courtesy", "prompt": "string", "when_to_use": "string"},
    {"order": 4, "principle": "Search for Truth", "prompt": "string", "when_to_use": "string"},
    {"order": 5, "principle": "Unity in Action", "prompt": "string", "when_to_use": "string"}
  ],
  "decision_record_template": "string, markdown formatted"
}

Section requirements:

1. purpose_statement. One sentence, decision-shaped, that the group can commit to before substantive discussion begins. It reformulates the input topic into a question or statement of decision. It is not a description of the meeting; it names what will be decided.

2. success_criteria. Exactly three specific markers the group will use to know whether the meeting actually produced a decision worth implementing. Each marker is observable from outside the room within two weeks of the meeting.

3. pre_meeting_questions. Three to five anonymous questions to send participants before the meeting so honest input is captured before bias sets in. Each question is tagged with the Principle it serves, drawn from the seven names above. Include at least one question tied to Detachment from Personal Views, one tied to Search for Truth, and one tied to Frankness with Courtesy.

4. facilitator_prompts. Exactly five in-session prompts the facilitator can use when the conversation needs intervention. Provide one prompt for each of: Spirit of Service (an opener), Equality of Voice (a surfacing prompt for unheard voices), Frankness with Courtesy (a dissent invitation), Search for Truth (an evidence request), and Unity in Action (a commitment question). Each prompt is one to two sentences. Each "when_to_use" note is one sentence and names a specific moment in the meeting.

5. decision_record_template. A markdown-formatted template for the meeting note-taker covering, in this order: Decision (one sentence), Rationale (a paragraph of three to five sentences with placeholders), Dissent Considered (a list with placeholders for named positions and why they were not adopted), and Unity-in-Action Commitments (a list with placeholders for owner names and deadlines).

Constraints:

- Do not invent content the input does not support. If the input is thin, produce conservative defaults that name the missing inputs in the template's placeholder text.
- Do not name any participant in the purpose statement, success criteria, pre-meeting questions, or facilitator prompts. Participants are named only in the decision record template's commitments section, and only with placeholders the note-taker will fill in.
- Use clear, plain English. Avoid management jargon and avoid the word "stakeholder" unless the input uses it first.
- Output JSON only. No preamble, no markdown code fences, no commentary. The first character of your output must be `{` and the last character must be `}`.
```

**`user_prompt_template`**:

```
Generate a Consultation Plan for the following meeting.

Meeting topic: {{topic}}

What is being decided: {{decision_paragraph}}

Duration: {{duration_minutes}} minutes

Participants:
{{participants_list}}

Additional context (recent history, prior attempts, sensitivities): {{context}}

Produce the JSON object now.
```

**Variables consumed**

| Variable | Source |
|---|---|
| `{{topic}}` | `Consultation#topic` |
| `{{decision_paragraph}}` | `Consultation#decision_paragraph` |
| `{{duration_minutes}}` | `Consultation#duration_minutes` |
| `{{participants_list}}` | Server-rendered from the consultation's participants as `- Name (Role)` lines |
| `{{context}}` | `Consultation#context`, defaulting to `(none provided)` if blank |

**`model`**: `gemini-2.0-flash`. The default. The output is structurally constrained so the cheaper model is sufficient.

**`max_output_tokens`**: 3000. Higher than the boilerplate default of 2000 because the five-part output plus a markdown decision record template can exceed 2000 in long meetings; raising the cap avoids truncated JSON which would fail the parse step.

**`temperature`**: 0.4. Lower than the boilerplate default of 0.7 because the output is structured JSON keyed to a fixed framework. Lower temperature reduces invented principles and improves JSON schema adherence; higher temperature increases creative variety but raises the risk of malformed output.

**`notes` (author's notes)**:

> The system prompt enforces the framework as structural slots: every principle must appear in the facilitator prompts, three principles must appear in the pre-meeting questions, and the decision record template must include all four named sections. Watch for these failure modes during iteration: (1) the model collapsing two principles into one prompt, (2) the model adding an eighth invented principle, (3) the model wrapping the JSON in markdown code fences (the boilerplate parser strips fences but it should not need to), (4) the model naming participants in the public-facing fields. If the output starts including new principles or skipping facilitator prompts, lower the temperature toward 0.2 first; if that does not fix it, tighten the system prompt's "you may not omit" language. The PREPE structure (Role, Explicit instructions, Parameters, Examples) is baked into the system prompt; the schema block plus the section requirements together act as the explicit instructions and parameters.

**Where it is called**: `ConsultationPlansController#create`.

**Expected output format**: A single JSON object matching the schema above.

**How the response is parsed and rendered**:

1. The raw string is stored in `gemini_raw`.
2. A defensive parse strips any leading or trailing markdown code fences (`` ```json `` or `` ``` ``) before `JSON.parse`.
3. On parse success, the five top-level keys are pulled out and stored in their respective columns (array-shaped fields are re-serialized to JSON for storage).
4. On parse failure, the controller still saves `gemini_raw` and renders an error message that exposes the "Show raw response" toggle so the user can read what Gemini actually returned.
5. The view layer pulls the array fields back through `success_criteria_array`, `pre_meeting_questions_array`, and `facilitator_prompts_array` reader methods on the model.

**Which domain field stores the raw response**: `consultation_plans.gemini_raw`. The `Show raw response` toggle on the show page reveals it.

This demo does not use Gemini's function calling. It is a single-shot prompt with structured JSON output. It does not use streaming, multi-step agents, or tools.

---

## 8. AI Safety Considerations (Specific to This App)

This is a moderate-stakes demo. The output is not consequential by itself; the consequence depends on whether a facilitator uses the prompts in a real meeting and whether the meeting's decisions are then implemented. Beyond what the boilerplate already provides (gatekeeper, budget cap, request log, timeout, raw response toggle, and footer disclaimer), the following considerations apply.

**Content sensitivity.** Meetings can be about personnel, strategy, governance, layoffs, or other sensitive topics. The decision paragraph and the context field are likely places where users would paste sensitive details. The README warns users not to paste real names, real personnel issues, or real legal matters into a local demo with no production data handling. Production ConsultationStarter has multi-tenant isolation, audit logging, and PII scrubbing; the demo does not.

**Consequential outputs.** A user acting on AI-suggested facilitator prompts in a real meeting could shape the decision in ways the AI did not anticipate. The risk is not catastrophic but it is real. The show page renders an app-specific note above the facilitator prompts list:

> AI-suggested facilitation language. Read each prompt before using it. Substitute your own when the AI's wording does not fit your group's relationships, history, or culture.

This note is present in addition to the boilerplate's footer disclaimer.

**Domain accuracy requirements.** The Seven Principles of Consultation are a defined framework with centuries of practitioner precedent. The system prompt names all seven explicitly and constrains the output so the model cannot invent new principles, drop existing ones, or rename them. During iteration, the admin should periodically test for principle drift (a previously-correct prompt starting to call "Equality of Voice" something like "Voice Equity" or similar) by reviewing recent `LlmRequest` records.

**App-specific disclaimers.**
- The footer's standard "AI-generated content can be incorrect" remains.
- The show page adds the facilitation-specific note above.
- The decision record template's preamble in the rendered output reads: `This template is a starting structure for the meeting note-taker. Edit freely to fit your group.`

**Tightened settings.** This demo justifies a lower temperature (0.4 vs. the boilerplate default of 0.7) for output predictability. The daily call cap and timeout are unchanged from the boilerplate defaults; this demo's call volume per user is naturally low because each consultation is regenerated only when inputs change.

**What this demo deliberately does NOT do, for safety reasons.**

- No persistence of decision content beyond the local database. There is no cloud sync, no team sharing, no shareable link.
- No collection of participant emails, last names, photos, or any other identifying information beyond a first name and a role label.
- No transcription, recording, or import of actual meeting content. The decision record template is a blank structure; the user fills it in by hand outside the app.
- No suggested decisions. The AI never tells the user what to decide; it produces only the structure for the conversation that produces the decision. This is the most important constraint in the system prompt.
- No meeting type heuristics that would push toward a specific facilitation philosophy. The Seven Principles are the only framework the app uses; if a user wants Roberts Rules or sociocracy, this is not their tool.

This list signals that the omissions are deliberate. An interviewer reading the spec sees explicit risk thinking, not absence of risk thinking.

---

## 9. RSpec Outline

Each new spec stubs `GeminiService.generate` via the boilerplate's test double; no actual API calls are made. The boilerplate's specs for `User`, `AiTemplate`, `LlmRequest`, `GeminiService`, `AiGatekeeper`, `AiBudgetChecker`, and the auth flows are inherited and not redescribed.

### `spec/models/consultation_spec.rb`

- Validates presence and length on `topic`, `decision_paragraph`, `duration_minutes`
- Validates `duration_minutes` numerical bounds (5 to 240)
- Custom validation: at least one participant required on save
- `belongs_to :user`, `has_many :participants`, `has_one :consultation_plan` associations
- Cascading destroy: deleting a consultation deletes its participants and plan

### `spec/models/participant_spec.rb`

- Validates presence of `name` and `role`
- `belongs_to :consultation`
- Destroy on parent consultation removes participant rows

### `spec/models/consultation_plan_spec.rb`

- Validates presence of all five structured fields and `gemini_raw`
- Unique `consultation_id` (one plan per consultation)
- `success_criteria_array`, `pre_meeting_questions_array`, `facilitator_prompts_array` parse stored JSON correctly
- These reader methods return empty arrays on malformed JSON instead of raising

### `spec/requests/consultations_spec.rb`

- `GET /consultations` requires authentication; redirects unauthenticated users to sign in
- A signed-in user sees only their own consultations, not another user's
- `POST /consultations` with valid params creates the record with nested participants
- `POST /consultations` with no participants returns the form with the validation error
- `PATCH /consultations/:id` updates the consultation and replaces participants via nested attributes
- `DELETE /consultations/:id` destroys the record and cascades to participants and plan
- A user attempting to access another user's consultation receives 404, not 403

### `spec/requests/consultation_plans_spec.rb`

- `POST /consultations/:id/plan` calls `GeminiService.generate` with the expected template name and variables (verified via the test double's call recorder)
- A successful call creates a `ConsultationPlan` record with all five fields populated and `gemini_raw` set
- A successful call creates exactly one `LlmRequest` record (verifying the boilerplate's logging fires on this demo's call path)
- A `GeminiService::BudgetExceededError` renders the boilerplate's error partial with budget-specific copy and does not create a plan
- A `GeminiService::TimeoutError` renders the error partial with timeout copy and a retry button
- A malformed JSON response from Gemini still saves `gemini_raw` and renders the show page with the parse error and Show raw response toggle expanded
- `POST /consultations/:id/plan` regenerates an existing plan (does not create a duplicate)
- `DELETE /consultations/:id/plan` removes the plan but leaves the consultation intact
- A user attempting to generate a plan on another user's consultation receives 404

No system specs are added in v1. The Stimulus participant-add behavior is exercised through the request spec for `POST /consultations` with multiple `participants_attributes` rows.

---

## 10. Seed Data

`db/seeds.rb` extends the boilerplate's seeded admin demo user with two parts.

### Part 1: AiTemplate seed

```ruby
AiTemplate.find_or_create_by!(name: "consultationstarter_meeting_plan_v1") do |t|
  t.description = "Generates a five-part Consultation Plan structured around the Seven Principles of Consultation."
  t.system_prompt = File.read(Rails.root.join("db/seeds/prompts/meeting_plan_system.txt"))
  t.user_prompt_template = File.read(Rails.root.join("db/seeds/prompts/meeting_plan_user.txt"))
  t.model = "gemini-2.0-flash"
  t.max_output_tokens = 3000
  t.temperature = 0.4
  t.notes = "Each principle is a structural slot. The model cannot omit a principle from facilitator prompts. Watch for invented principles, code-fence wrapping of the JSON, and participant-naming in public fields."
end
```

The system and user prompt strings are extracted into `db/seeds/prompts/` files so the seed file stays readable and the prompt text can be diffed cleanly across versions. The two files contain exactly the text in Section 7.

### Part 2: Domain seed

One realistic sample consultation belonging to the seeded admin user, with three participants and a saved sample plan so the show page is meaningful on first run.

```ruby
admin = User.find_by!(email: "demo@example.com")

consultation = admin.consultations.find_or_create_by!(topic: "Reallocate Q1 marketing budget after the channel mix audit") do |c|
  c.decision_paragraph = "We have audited Q1 channel performance. Paid social underperformed against the prior quarter while organic content and partnerships outperformed. We need to decide whether to shift roughly 40 percent of the paid social budget into the two outperforming channels for the remainder of the quarter, hold steady and gather another month of data, or fully exit paid social through Q2."
  c.duration_minutes = 60
  c.context = "Last quarter the team chose to hold steady against weak data and lost two months. Two participants disagreed publicly with that decision and have since asked whether their dissent was actually considered."
  c.scheduled_for = 2.days.from_now.change(hour: 14)
end

[
  { name: "Maya",   role: "Head of Marketing" },
  { name: "Devon",  role: "Performance Marketing Lead" },
  { name: "Priya",  role: "Brand and Content Lead" }
].each do |attrs|
  consultation.participants.find_or_create_by!(name: attrs[:name]) { |p| p.role = attrs[:role] }
end

# A pre-generated plan so the show page is populated on first run without spending a Gemini call.
consultation.consultation_plan ||= ConsultationPlan.create!(
  consultation: consultation,
  purpose_statement: "Decide whether to shift, hold, or exit paid social for the remainder of Q1, with a clear trigger for revisiting the decision.",
  success_criteria: [
    "A single named option is chosen, with the dissenting positions recorded.",
    "Owners and deadlines are assigned for the first two weeks of the new allocation.",
    "A revisit date and a clear data trigger for that revisit are written into the decision record."
  ].to_json,
  pre_meeting_questions: [
    { question: "What outcome would make you confident the right call was made, regardless of which option is chosen?", principle: "Detachment from Personal Views" },
    { question: "What evidence would change your current preference?", principle: "Search for Truth" },
    { question: "Is there anything you would say in this meeting only if you were sure it would not affect your standing on the team?", principle: "Frankness with Courtesy" }
  ].to_json,
  facilitator_prompts: [
    { order: 1, principle: "Spirit of Service",        prompt: "Before we start, what is the best possible outcome for the customers and the team, separate from any of our individual positions?",                                  when_to_use: "Use as the opening question, before substantive discussion." },
    { order: 2, principle: "Equality of Voice",        prompt: "We have heard from two voices on this. Before we move on, I would like to invite anyone who has not weighed in to share their read.",                                  when_to_use: "Use when one or two participants have dominated the first ten minutes." },
    { order: 3, principle: "Frankness with Courtesy",  prompt: "If anyone disagrees with where this is heading and has not said so, this is the moment. The decision will be more durable if dissent is on the record now.",          when_to_use: "Use just before the group converges on a tentative direction." },
    { order: 4, principle: "Search for Truth",         prompt: "What evidence would tell us in two weeks that this was the wrong call? Let us name that now so we know what to look for.",                                              when_to_use: "Use after a tentative decision but before commitments are assigned." },
    { order: 5, principle: "Unity in Action",          prompt: "Regardless of which position each of you held, can each of you commit to one specific action this week that supports the decision the group is making?",              when_to_use: "Use as the closing question, after the decision is made." }
  ].to_json,
  decision_record_template: <<~MD,
    ## Decision
    [One sentence naming what was decided.]

    ## Rationale
    [Three to five sentences explaining why this option was chosen over the alternatives, including the evidence that mattered most.]

    ## Dissent Considered
    - [Name] argued for [position] because [reasoning]. The group did not adopt this because [reason].
    - [Name] argued for [position] because [reasoning]. The group did not adopt this because [reason].

    ## Unity-in-Action Commitments
    - [Name] will [action] by [date].
    - [Name] will [action] by [date].
    - Revisit date: [date]. Revisit trigger: [data condition].
  MD
  gemini_raw: '{"purpose_statement":"...","success_criteria":["...","...","..."],"...":"..."}'
)
```

The seeded plan is a hand-written example that matches the shape of a real Gemini output. The `gemini_raw` value is intentionally minimal so the raw-response toggle has something to show without requiring a real API call during seed.

---

## 11. README Additions

The boilerplate's README template provides the standard `Stack`, `Setup`, `License`, `AI Safety Posture`, and `About the Author` sections. This demo overrides or extends the following.

### App name and tagline

> **ConsultationStarter Demo**
>
> Describe the decision. Get a meeting plan that produces a real conversation.

### One-paragraph description

ConsultationStarter Demo turns a one-paragraph description of a decision into a complete meeting plan structured around the Seven Principles of Consultation. Enter your topic, what you are deciding, your participants, and the duration; receive a sharpened purpose statement, three success criteria, anonymous pre-meeting questions, in-session facilitator prompts mapped to the principles, and a decision record template ready to copy into your note-taker.

### Screenshot placeholder

`docs/screenshot.png` (placeholder; replace with a screenshot of `consultations/show.html.erb` after seeding the demo data).

### Why I built this

I am building ConsultationStarter, a multi-tenant SaaS that gives recurring decision-making bodies (executive teams, boards, committees, councils, faith-community bodies, cooperative circles) a meeting practice grounded in the Seven Principles. The full product has team collaboration, async pre-meeting input, in-session principle checks, longitudinal scorecards across a year of meetings, and a follow-through tracker. This demo strips all of that out and isolates the meeting-plan engine: the moment where a vague topic becomes a structure a group can actually consult inside of.

It is open source under the MIT license because the framework is too valuable to lock behind a single product. If you clone it and use it once a month for the next year, that is a win. If you fork it and extend it for your own context, that is a bigger win.

The production app's landing page lives at `https://consultationstarter.com` (placeholder until shipped).

### Editing the AI prompt

The single AI template this demo uses (`consultationstarter_meeting_plan_v1`) is editable in the admin panel at `/admin/ai_templates`. After running `bin/setup`, sign in as the seeded admin (`demo@example.com` / `password123`), navigate to the template, and use the live test panel on the right to iterate on prompt changes against your own sample inputs before saving. This is the same workflow I use for every prompt in the larger product.

### Setup

No app-specific setup beyond the boilerplate's `bin/setup` is required. There is no Serper.dev API key, no background job runner, no extra service. You need a `GEMINI_API_KEY` in `.env` and you are ready to run.

The boilerplate's standard `Stack`, `License`, `AI Safety Posture`, and `About the Author` sections remain unchanged.

---

## 12. Bootstrap Dark Mode and Accent Color Notes

**UX pattern.** Form-then-result with a persistent right sidebar. The form lives at `/consultations/new` (and the equivalent edit). The result is the show page, which renders the plan as a printable one-pager in the main column with the Seven Principles checklist permanently visible in the right sidebar.

**Component choices.**
- Card-based layout for the show page. Each of the five plan sections is a Bootstrap `card` with a colored header strip in `var(--accent)`.
- Card-grid layout for the dashboard and consultations index. Three columns on desktop, one on mobile.
- Stacked form layout (no horizontal forms) for the new and edit pages. Clear vertical rhythm. Bootstrap `form-floating` is not used; plain labels above inputs read more cleanly in dark mode.
- Bootstrap `badge` components for the principle tags on pre-meeting questions and facilitator prompts. Each badge uses `var(--accent)` as background.
- Bootstrap `collapse` for the `Show raw response` toggle, inherited from the boilerplate's expectation.

**Accent color application.** `--accent: #0c4a6e` (deep ocean blue) and `--accent-hover: #075985` are set in `_accent.scss` and applied to:
- Primary buttons (`.btn-primary` overridden via Bootstrap variable map)
- Active navbar link state
- Card header strips on the show page (left border 4px solid `var(--accent)`)
- Principle badges
- Links inside the main content area
- The `Generate Plan` and `Regenerate Plan` CTAs

The deep ocean blue reads as steady and considered against Bootstrap dark mode's neutral grays. It does not compete with the meeting content; it frames it.

**Sidebar layout.** The Seven Principles checklist sidebar is a sticky-positioned card in a Bootstrap `col-lg-4` with `position: sticky; top: 1rem;`. Below the `lg` breakpoint, the sidebar collapses to a button in the main content header that opens a Bootstrap `offcanvas` from the right edge. Checkbox state persists in `localStorage` keyed by consultation ID, scoped to the user's browser only.

**Custom CSS beyond the boilerplate.** Minimal. The accent overrides live in `_accent.scss`. Two small additions go in `app/assets/stylesheets/application.css`:

```css
.principle-badge {
  background-color: var(--accent);
  color: #fff;
  font-weight: 500;
  letter-spacing: 0.01em;
}

.plan-section-card {
  border-left: 4px solid var(--accent);
}

.principle-checklist .form-check-input:checked {
  background-color: var(--accent);
  border-color: var(--accent);
}
```

Everything else is Bootstrap utilities. No custom typography, no custom spacing scale, no JavaScript beyond the two Stimulus controllers (one for the participant-add behavior, one for the copy-to-clipboard button on the decision record template).

---

*v1.0 - ConsultationStarter Demo spec. Built on Open Demo Starter v2.0. Open source under MIT license.*
