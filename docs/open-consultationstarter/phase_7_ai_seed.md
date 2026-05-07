# Phase 7 — AI Template, Gemini Integration & Seed Data

**Builds on:** Phase 6 complete (show page and plan views render). Phase 2 models migrated. Phase 3 controller stubs exist.
**Reference docs:** [`docs/ai-templates.md`](../ai-templates.md) — GeminiService call pattern, template seeding, working model names. [`docs/ai-guardrails.md`](../ai-guardrails.md) — error classes and how to rescue them. [`CLAUDE.md`](../../CLAUDE.md) — never call Gemini directly, always through GeminiService.
**Goal:** The plan-generation flow works end-to-end; seeds produce a populated show page on first run without spending a real Gemini call.

---

## Deliverables

### 1. Create `db/seeds/prompts/` directory

```bash
mkdir -p db/seeds/prompts
```

---

### 2. `db/seeds/prompts/meeting_plan_system.txt`

Create this file with the exact system prompt text (copy verbatim — precision matters for the Seven Principles constraint):

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
- Output JSON only. No preamble, no markdown code fences, no commentary. The first character of your output must be { and the last character must be }.
```

---

### 3. `db/seeds/prompts/meeting_plan_user.txt`

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

---

### 4. `db/seeds.rb` — extend with AI template and domain seed

Append to the existing boilerplate seeds (do not replace them):

```ruby
# ── AI Template ─────────────────────────────────────────────────────────────
AiTemplate.find_or_create_by!(name: "consultationstarter_meeting_plan_v1") do |t|
  t.description = "Generates a five-part Consultation Plan structured around the Seven Principles of Consultation."
  t.system_prompt = File.read(Rails.root.join("db/seeds/prompts/meeting_plan_system.txt"))
  t.user_prompt_template = File.read(Rails.root.join("db/seeds/prompts/meeting_plan_user.txt"))
  t.model = "gemini-2.5-flash"
  t.max_output_tokens = 3000
  t.temperature = 0.4
  t.notes = "Each principle is a structural slot. The model cannot omit a principle from facilitator prompts. Watch for: invented principles, code-fence wrapping of JSON output, participant naming in public fields."
end

# ── Sample Consultation ──────────────────────────────────────────────────────
admin = User.find_by!(email: "demo@example.com")

consultation = admin.consultations.find_or_create_by!(
  topic: "Reallocate Q1 marketing budget after the channel mix audit"
) do |c|
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

# Pre-generated plan — no Gemini call needed on seed.
unless consultation.consultation_plan
  ConsultationPlan.create!(
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
      { order: 1, principle: "Spirit of Service",       prompt: "Before we start, what is the best possible outcome for the customers and the team, separate from any of our individual positions?",                                   when_to_use: "Use as the opening question, before substantive discussion." },
      { order: 2, principle: "Equality of Voice",       prompt: "We have heard from two voices on this. Before we move on, I would like to invite anyone who has not weighed in to share their read.",                                   when_to_use: "Use when one or two participants have dominated the first ten minutes." },
      { order: 3, principle: "Frankness with Courtesy", prompt: "If anyone disagrees with where this is heading and has not said so, this is the moment. The decision will be more durable if dissent is on the record now.",           when_to_use: "Use just before the group converges on a tentative direction." },
      { order: 4, principle: "Search for Truth",        prompt: "What evidence would tell us in two weeks that this was the wrong call? Let us name that now so we know what to look for.",                                               when_to_use: "Use after a tentative decision but before commitments are assigned." },
      { order: 5, principle: "Unity in Action",         prompt: "Regardless of which position each of you held, can each of you commit to one specific action this week that supports the decision the group is making?",               when_to_use: "Use as the closing question, after the decision is made." }
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
    gemini_raw: '{"purpose_statement":"Decide whether to shift, hold, or exit paid social for the remainder of Q1, with a clear trigger for revisiting the decision.","success_criteria":["A single named option is chosen, with the dissenting positions recorded.","Owners and deadlines are assigned for the first two weeks of the new allocation.","A revisit date and a clear data trigger for that revisit are written into the decision record."],"pre_meeting_questions":[{"question":"What outcome would make you confident the right call was made, regardless of which option is chosen?","principle":"Detachment from Personal Views"},{"question":"What evidence would change your current preference?","principle":"Search for Truth"},{"question":"Is there anything you would say in this meeting only if you were sure it would not affect your standing on the team?","principle":"Frankness with Courtesy"}],"facilitator_prompts":[{"order":1,"principle":"Spirit of Service","prompt":"Before we start, what is the best possible outcome for the customers and the team, separate from any of our individual positions?","when_to_use":"Use as the opening question, before substantive discussion."},{"order":2,"principle":"Equality of Voice","prompt":"We have heard from two voices on this. Before we move on, I would like to invite anyone who has not weighed in to share their read.","when_to_use":"Use when one or two participants have dominated the first ten minutes."},{"order":3,"principle":"Frankness with Courtesy","prompt":"If anyone disagrees with where this is heading and has not said so, this is the moment. The decision will be more durable if dissent is on the record now.","when_to_use":"Use just before the group converges on a tentative direction."},{"order":4,"principle":"Search for Truth","prompt":"What evidence would tell us in two weeks that this was the wrong call? Let us name that now so we know what to look for.","when_to_use":"Use after a tentative decision but before commitments are assigned."},{"order":5,"principle":"Unity in Action","prompt":"Regardless of which position each of you held, can each of you commit to one specific action this week that supports the decision the group is making?","when_to_use":"Use as the closing question, after the decision is made."}],"decision_record_template":"## Decision\n[One sentence naming what was decided.]\n\n## Rationale\n[Three to five sentences.]\n\n## Dissent Considered\n- [placeholder]\n\n## Unity-in-Action Commitments\n- [placeholder]"}'
  )
end
```

---

### 5. Complete `app/controllers/consultation_plans_controller.rb#create`

Replace the Phase 3 stub with the full implementation:

```ruby
def create
  result = GeminiService.generate(
    template: "consultationstarter_meeting_plan_v1",
    variables: {
      topic:              @consultation.topic,
      decision_paragraph: @consultation.decision_paragraph,
      duration_minutes:   @consultation.duration_minutes,
      context:            @consultation.context.presence || "(none provided)",
      participants_list:  @consultation.participants.map { |p| "- #{p.name} (#{p.role})" }.join("\n")
    }
  )

  plan = @consultation.consultation_plan || @consultation.build_consultation_plan
  stripped = result.gsub(/\A```(?:json)?\n?/, "").gsub(/\n?```\z/, "")

  ActiveRecord::Base.transaction do
    parsed = JSON.parse(stripped)
    plan.assign_attributes(
      purpose_statement:        parsed["purpose_statement"],
      success_criteria:         parsed["success_criteria"].to_json,
      pre_meeting_questions:    parsed["pre_meeting_questions"].to_json,
      facilitator_prompts:      parsed["facilitator_prompts"].to_json,
      decision_record_template: parsed["decision_record_template"],
      gemini_raw:               result
    )
    plan.save!
  end

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.update("plan-region") do
        render partial: "consultation_plans/plan", locals: { plan: plan, consultation: @consultation }
      end
    end
    format.html { redirect_to consultation_path(@consultation) }
  end

rescue JSON::ParserError
  plan.update_column(:gemini_raw, result) if plan.persisted?
  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.update("plan-region") do
        render partial: "consultation_plans/parse_error", locals: { raw: result, consultation: @consultation }
      end
    end
    format.html { redirect_to consultation_path(@consultation), alert: "Plan generated but response could not be parsed. See raw output." }
  end
rescue GeminiService::BudgetExceededError
  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.update("plan-region") do
        render partial: "shared/ai_error", locals: { error_type: :budget_exceeded, consultation: @consultation }
      end
    end
    format.html { redirect_to consultation_path(@consultation), alert: "Daily AI limit reached." }
  end
rescue GeminiService::GatekeeperError
  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.update("plan-region") do
        render partial: "shared/ai_error", locals: { error_type: :gatekeeper_blocked, consultation: @consultation }
      end
    end
    format.html { redirect_to consultation_path(@consultation), alert: "Input blocked by content filter." }
  end
rescue GeminiService::TimeoutError
  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.update("plan-region") do
        render partial: "shared/ai_error", locals: { error_type: :timeout, consultation: @consultation }
      end
    end
    format.html { redirect_to consultation_path(@consultation), alert: "Gemini timed out. Try again." }
  end
rescue GeminiService::GeminiError
  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.update("plan-region") do
        render partial: "shared/ai_error", locals: { error_type: :error, consultation: @consultation }
      end
    end
    format.html { redirect_to consultation_path(@consultation), alert: "AI error. Try again." }
  end
end
```

**Transaction scope:** `JSON.parse` and `plan.save!` are inside a single `ActiveRecord::Base.transaction`. If the parse succeeds but save fails, the transaction rolls back and the prior plan (if any) is preserved intact.

---

### 6. `app/views/consultation_plans/_parse_error.html.erb`

```erb
<%# Receives: raw (String), consultation (Consultation) %>
<div class="alert alert-warning mb-3">
  <strong>Unexpected response format.</strong>
  The plan was generated but Gemini returned output that could not be parsed as JSON.
  The raw response is shown below.
</div>

<div class="mb-3">
  <%= button_to "Try Again",
      consultation_plan_path(consultation),
      method: :post,
      class: "btn btn-primary" %>
</div>

<div class="card bg-dark border-secondary">
  <div class="card-body">
    <pre class="text-muted small mb-0" style="white-space: pre-wrap;"><%= raw_response %></pre>
  </div>
</div>
```

---

## Manual Checks

- [ ] `rails db:seed` completes without errors (run `rails db:seed` or `rails db:reset` if needed).
- [ ] Sign in as `demo@example.com`. Dashboard shows the seeded Q1 marketing consultation card with "Plan generated" badge.
- [ ] Show page for the seeded consultation renders all five plan sections (Purpose, Success Criteria, Pre-Meeting Questions, Facilitator Prompts, Decision Record Template).
- [ ] "Show raw Gemini response" collapse toggle works.
- [ ] Verify `GEMINI_API_KEY` is set in `.env`. Click "Regenerate Plan" on the seeded consultation — Gemini responds and the plan region updates in place via Turbo Stream.
- [ ] After regeneration, the new plan appears without a full page reload.
- [ ] Temporarily remove `GEMINI_API_KEY` from `.env` and restart the server. Click "Generate Plan" on a new consultation — an error partial appears in the `plan-region` (not a 500 error).
- [ ] Restore the API key.
- [ ] Admin panel: `/admin/ai_templates` shows the `consultationstarter_meeting_plan_v1` template. Use the test panel to send a real test prompt.

---

## Acceptance Criteria

- [ ] `db/seeds/prompts/meeting_plan_system.txt` and `meeting_plan_user.txt` exist with exact prompt text.
- [ ] `db/seeds.rb` seeds the AI template with `gemini-2.5-flash`, `max_output_tokens: 3000`, `temperature: 0.4`.
- [ ] Seed creates the sample consultation with three participants and a pre-generated plan.
- [ ] `ConsultationPlansController#create` calls `GeminiService.generate` with the template name and all five variable keys.
- [ ] The `create` action rescues all four `GeminiService` error classes and responds with the appropriate Turbo Stream or redirect.
- [ ] `_parse_error.html.erb` partial exists.
- [ ] All Turbo Stream responses use `turbo_stream.update` — never `turbo_stream.replace`.
