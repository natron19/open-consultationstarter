# Phase 6 — Consultation Show Page & Plan Views

**Builds on:** Phase 5 complete (consultations CRUD UI works).
**Reference docs:** [`CLAUDE.md`](../../CLAUDE.md) — Turbo Stream `update()` not `replace()`, Stimulus only, no plain JS. [`docs/turbo-stimulus-patterns.md`](../turbo-stimulus-patterns.md) — Turbo Frame patterns.
**Goal:** The consultation show page renders the five-part plan in the correct layout, the seven-principles sidebar persists checkbox state in localStorage, and the copy-to-clipboard button works.

---

## Deliverables

### 1. `app/javascript/controllers/clipboard_controller.js` (Stimulus)

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    const text = this.sourceTarget.textContent
    navigator.clipboard.writeText(text).then(() => {
      const original = this.buttonTarget.textContent
      this.buttonTarget.textContent = "Copied!"
      setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
    })
  }
}
```

Register in `app/javascript/controllers/index.js`:

```javascript
import ClipboardController from "./clipboard_controller"
application.register("clipboard", ClipboardController)
```

---

### 2. `app/javascript/controllers/principles_checklist_controller.js` (Stimulus)

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]
  static values = { consultationId: String }

  connect() {
    const stored = localStorage.getItem(this.storageKey)
    if (!stored) return
    const checked = JSON.parse(stored)
    this.checkboxTargets.forEach((cb, i) => {
      cb.checked = checked.includes(i)
    })
  }

  save() {
    const checked = this.checkboxTargets
      .map((cb, i) => cb.checked ? i : null)
      .filter(i => i !== null)
    localStorage.setItem(this.storageKey, JSON.stringify(checked))
  }

  get storageKey() {
    return `cs_principles_${this.consultationIdValue}`
  }
}
```

Register in `app/javascript/controllers/index.js`:

```javascript
import PrinciplesChecklistController from "./principles_checklist_controller"
application.register("principles-checklist", PrinciplesChecklistController)
```

---

### 3. `app/views/shared/_seven_principles_sidebar.html.erb`

```erb
<%# Receives: consultation (Consultation object) %>
<div class="card bg-dark border-secondary"
     data-controller="principles-checklist"
     data-principles-checklist-consultation-id-value="<%= consultation.id %>">
  <div class="card-header fw-semibold small text-uppercase text-muted">
    Use during the meeting
  </div>
  <div class="card-body p-3">
    <ul class="list-unstyled mb-0 principle-checklist">
      <%
        principles = [
          { name: "Spirit of Service",           desc: "Each participant enters to advance the collective purpose, not their own position." },
          { name: "Unity of Purpose",            desc: "The meeting question is explicit, shared, and revisited when discussion drifts." },
          { name: "Detachment from Personal Views", desc: "Ideas are evaluated on merit, not on who proposed them." },
          { name: "Frankness with Courtesy",     desc: "Dissent is welcomed; honesty is delivered to make it easier for others to be honest." },
          { name: "Equality of Voice",           desc: "Every participant with relevant perspective has meaningful opportunity to shape the outcome." },
          { name: "Search for Truth",            desc: "Decisions are based on evidence, including evidence that contradicts what the group prefers." },
          { name: "Unity in Action",             desc: "After the decision, the group implements together regardless of each person's prior position." }
        ]
      %>
      <% principles.each_with_index do |p, i| %>
        <li class="mb-3">
          <div class="form-check">
            <input class="form-check-input"
                   type="checkbox"
                   id="principle-<%= i %>"
                   data-principles-checklist-target="checkbox"
                   data-action="change->principles-checklist#save"
                   data-principle-index="<%= i %>">
            <label class="form-check-label fw-semibold small" for="principle-<%= i %>">
              <%= p[:name] %>
            </label>
          </div>
          <p class="text-muted small mb-0 ms-4"><%= p[:desc] %></p>
        </li>
      <% end %>
    </ul>
    <p class="text-muted" style="font-size: 0.7rem;" class="mb-0">
      Checkboxes are saved in your browser only and reset when you regenerate the plan.
    </p>
  </div>
</div>
```

---

### 4. `app/views/consultation_plans/_plan.html.erb`

The plan partial rendered inside the `plan-region` Turbo Frame. Receives locals: `plan`, `consultation`.

```erb
<%# Purpose statement %>
<div class="card bg-dark border-secondary plan-section-card mb-3">
  <div class="card-body">
    <h6 class="text-muted text-uppercase small mb-2">Purpose Statement</h6>
    <p class="fs-5 mb-0"><%= plan.purpose_statement %></p>
  </div>
</div>

<%# Success criteria %>
<div class="card bg-dark border-secondary plan-section-card mb-3">
  <div class="card-body">
    <h6 class="text-muted text-uppercase small mb-2">Success Criteria</h6>
    <% if plan.success_criteria_array.any? %>
      <ol class="mb-0">
        <% plan.success_criteria_array.each do |criterion| %>
          <li><%= criterion %></li>
        <% end %>
      </ol>
    <% else %>
      <p class="text-muted small mb-0">Could not parse success criteria.</p>
    <% end %>
  </div>
</div>

<%# Pre-meeting questions %>
<div class="card bg-dark border-secondary plan-section-card mb-3">
  <div class="card-body">
    <h6 class="text-muted text-uppercase small mb-2">Pre-Meeting Questions</h6>
    <% if plan.pre_meeting_questions_array.any? %>
      <ul class="list-unstyled mb-0">
        <% plan.pre_meeting_questions_array.each do |q| %>
          <li class="mb-2 d-flex justify-content-between align-items-start gap-3">
            <span><%= q["question"] %></span>
            <span class="badge principle-badge flex-shrink-0"><%= q["principle"] %></span>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="text-muted small mb-0">Could not parse pre-meeting questions.</p>
    <% end %>
  </div>
</div>

<%# Facilitator prompts %>
<div class="card bg-dark border-secondary plan-section-card mb-3">
  <div class="card-body">
    <h6 class="text-muted text-uppercase small mb-2">Facilitator Prompts</h6>
    <p class="text-muted small fst-italic mb-3">
      AI-suggested facilitation language. Read each prompt before using it. Substitute your own when the AI's wording does not fit your group's relationships, history, or culture.
    </p>
    <% if plan.facilitator_prompts_array.any? %>
      <ol class="mb-0">
        <% plan.facilitator_prompts_array.each do |fp| %>
          <li class="mb-3">
            <div class="d-flex justify-content-between align-items-start gap-3 mb-1">
              <span class="fw-medium"><%= fp["prompt"] %></span>
              <span class="badge principle-badge flex-shrink-0"><%= fp["principle"] %></span>
            </div>
            <p class="text-muted small mb-0"><em><%= fp["when_to_use"] %></em></p>
          </li>
        <% end %>
      </ol>
    <% else %>
      <p class="text-muted small mb-0">Could not parse facilitator prompts.</p>
    <% end %>
  </div>
</div>

<%# Decision record template %>
<div class="card bg-dark border-secondary plan-section-card mb-3"
     data-controller="clipboard">
  <div class="card-body">
    <div class="d-flex justify-content-between align-items-center mb-2">
      <h6 class="text-muted text-uppercase small mb-0">Decision Record Template</h6>
      <button class="btn btn-sm btn-outline-secondary"
              data-action="click->clipboard#copy"
              data-clipboard-target="button">
        Copy to clipboard
      </button>
    </div>
    <p class="text-muted small fst-italic mb-2">
      This template is a starting structure for the meeting note-taker. Edit freely to fit your group.
    </p>
    <pre class="text-muted small mb-0" data-clipboard-target="source" style="white-space: pre-wrap;"><%= plan.decision_record_template %></pre>
  </div>
</div>

<%# Plan footer: raw response toggle + regenerate %>
<div class="d-flex justify-content-between align-items-center mb-2">
  <button class="btn btn-sm btn-link text-muted p-0"
          type="button"
          data-bs-toggle="collapse"
          data-bs-target="#raw-response-collapse">
    Show raw Gemini response
  </button>
  <%= button_to "Regenerate Plan",
      consultation_plan_path(consultation),
      method: :post,
      class: "btn btn-sm btn-outline-secondary",
      data: { turbo_confirm: "Regenerate this plan? The current plan will be replaced." } %>
</div>

<div class="collapse" id="raw-response-collapse">
  <div class="card bg-dark border-secondary">
    <div class="card-body">
      <pre class="text-muted small mb-0" style="white-space: pre-wrap; overflow-x: auto;"><%= plan.gemini_raw %></pre>
    </div>
  </div>
</div>
```

---

### 5. `app/views/consultations/_no_plan_cta.html.erb`

Used by `ConsultationPlansController#destroy` to restore the plan region to its "no plan" state. Also used directly in `show.html.erb`.

```erb
<%# Receives: consultation %>
<div class="card bg-dark border-secondary plan-section-card">
  <div class="card-body text-center py-5">
    <h5 class="mb-2">Generate Your Consultation Plan</h5>
    <p class="text-muted mb-4">
      Click below to generate a purpose statement, success criteria, pre-meeting questions,
      facilitator prompts, and a decision record template — all structured around the Seven Principles.
    </p>
    <%= button_to "Generate Plan",
        consultation_plan_path(consultation),
        method: :post,
        class: "btn btn-primary" %>
  </div>
</div>
```

---

### 6. `app/views/consultations/show.html.erb`

```erb
<div class="container py-4">
  <div class="row g-4">
    <%# Main column %>
    <div class="col-lg-8">
      <%# Header %>
      <div class="mb-4">
        <h1 class="display-6 fw-bold mb-1"><%= @consultation.topic %></h1>
        <p class="text-muted small mb-2">
          <% if @consultation.scheduled_for %>
            <%= @consultation.scheduled_for.strftime("%B %-d, %Y at %-I:%M %p") %> &middot;
          <% end %>
          <%= @consultation.duration_minutes %> min &middot;
          <%= pluralize(@consultation.participants.size, "participant") %>
        </p>
        <div class="d-flex gap-2">
          <%= link_to "Edit", edit_consultation_path(@consultation), class: "btn btn-sm btn-outline-secondary" %>
          <%= button_to "Delete", consultation_path(@consultation), method: :delete,
              class: "btn btn-sm btn-outline-danger",
              data: { turbo_confirm: "Delete this consultation and its plan?" } %>
          <%# Mobile: sidebar toggle %>
          <button class="btn btn-sm btn-outline-secondary d-lg-none ms-auto"
                  type="button"
                  data-bs-toggle="offcanvas"
                  data-bs-target="#principles-offcanvas">
            View Principles
          </button>
        </div>
      </div>

      <%# Stale plan notice %>
      <% if @plan && @consultation.updated_at > @plan.created_at %>
        <div class="alert alert-info small mb-3">
          Inputs updated since this plan was generated — consider regenerating.
        </div>
      <% end %>

      <%# Plan region — Turbo Frame %>
      <%= turbo_frame_tag "plan-region" do %>
        <% if @plan %>
          <%= render "consultation_plans/plan", plan: @plan, consultation: @consultation %>
        <% else %>
          <%= render "no_plan_cta", consultation: @consultation %>
        <% end %>
      <% end %>
    </div>

    <%# Desktop sidebar %>
    <div class="col-lg-4 d-none d-lg-block">
      <%= render "shared/seven_principles_sidebar", consultation: @consultation %>
    </div>
  </div>
</div>

<%# Mobile offcanvas sidebar %>
<div class="offcanvas offcanvas-end d-lg-none bg-dark" tabindex="-1" id="principles-offcanvas">
  <div class="offcanvas-header border-bottom border-secondary">
    <h6 class="offcanvas-title">Seven Principles</h6>
    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="offcanvas"></button>
  </div>
  <div class="offcanvas-body">
    <%= render "shared/seven_principles_sidebar", consultation: @consultation %>
  </div>
</div>
```

**Key rule:** The `plan-region` Turbo Frame uses `turbo_frame_tag` in the view. The controller responds with `turbo_stream.update("plan-region", ...)` — `update`, never `replace`. If you use `replace`, Stimulus bindings inside the frame break after the first update.

---

## Manual Checks

- [ ] Show page renders the header (topic, duration, participant count) and the "Generate Plan" CTA when no plan exists.
- [ ] Seven principles sidebar is visible on desktop (right column). All seven principles are listed with checkboxes.
- [ ] Check a principle checkbox. Hard-refresh the page. The checkbox is still checked (localStorage persisted).
- [ ] Open browser dev tools → Application → Local Storage: confirm a key `cs_principles_<id>` exists.
- [ ] "View Principles" button appears on mobile viewport and opens the offcanvas sidebar.
- [ ] After seeding the demo data (Phase 7), the show page for the seeded consultation renders all five plan sections.
- [ ] "Copy to clipboard" button copies the decision record template text. Button briefly reads "Copied!".
- [ ] "Show raw Gemini response" toggle expands/collapses the raw JSON.
- [ ] Stale plan notice appears after editing a consultation that already has a plan.

---

## Acceptance Criteria

- [ ] `clipboard_controller.js` and `principles_checklist_controller.js` registered in `controllers/index.js`.
- [ ] `_seven_principles_sidebar.html.erb` uses `data-controller="principles-checklist"` and `data-principles-checklist-consultation-id-value` — no hardcoded principle state.
- [ ] `_plan.html.erb` renders all five sections; facilitator prompts section includes the AI disclaimer note.
- [ ] `show.html.erb` wraps the plan region in `turbo_frame_tag "plan-region"`.
- [ ] `_no_plan_cta.html.erb` exists and is used in both show page and `ConsultationPlansController#destroy`.
- [ ] No `onclick`, `addEventListener`, or `<script>` tags in any of these views or controllers.
