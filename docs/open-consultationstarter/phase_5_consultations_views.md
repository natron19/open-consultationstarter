# Phase 5 — Consultations List & Form Views

**Builds on:** Phase 4 complete (home and dashboard views render).
**Reference docs:** [`CLAUDE.md`](../../CLAUDE.md) — Stimulus-only JS rule, no plain JavaScript, no `onclick`. [`docs/turbo-stimulus-patterns.md`](../turbo-stimulus-patterns.md) — Stimulus controller patterns, target and action descriptors.
**Goal:** Full CRUD UI for consultations works, including the dynamic participant row add/remove behavior driven by a Stimulus controller.

---

## Deliverables

### 1. `app/javascript/controllers/participants_controller.js` (Stimulus)

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container", "row"]

  connect() {
    while (this.rowTargets.length < 2) {
      this.addParticipant()
    }
  }

  addParticipant() {
    const template = this.templateTarget.innerHTML
    const index = Date.now()
    const html = template.replace(/PARTICIPANT_INDEX/g, index)
    this.containerTarget.insertAdjacentHTML("beforeend", html)
  }

  removeParticipant(event) {
    const row = event.target.closest("[data-participants-target='row']")
    const destroyField = row.querySelector(".destroy-field")

    if (destroyField) {
      destroyField.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }
  }
}
```

Register this controller in `app/javascript/controllers/index.js`:

```javascript
import ParticipantsController from "./participants_controller"
application.register("participants", ParticipantsController)
```

**Why `Date.now()` for index:** Rails treats nested attribute keys as opaque strings; using `Date.now()` guarantees uniqueness for new rows added during the same page session, preventing Rails from merging them as updates to the same record.

---

### 2. `app/views/consultations/_participant_fields.html.erb` (Rails form fragment)

Used by `fields_for` for existing persisted participants:

```erb
<div class="row g-2 mb-2 participant-row" data-participants-target="row">
  <div class="col-5">
    <%= form.text_field :name, placeholder: "First name or pseudonym",
        class: "form-control form-control-sm" %>
  </div>
  <div class="col-5">
    <%= form.text_field :role, placeholder: "Role in the room",
        class: "form-control form-control-sm" %>
  </div>
  <div class="col-2">
    <button type="button" class="btn btn-sm btn-outline-danger w-100"
            data-action="click->participants#removeParticipant">
      Remove
    </button>
  </div>
  <%= form.hidden_field :id %>
  <%= form.hidden_field :_destroy, value: false, class: "destroy-field" %>
</div>
```

---

### 3. `app/views/consultations/_form.html.erb`

```erb
<%= form_with model: consultation do |form| %>
  <% if consultation.errors.any? %>
    <div class="alert alert-danger mb-4">
      <ul class="mb-0">
        <% consultation.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="mb-3">
    <%= form.label :topic, "Meeting Topic", class: "form-label" %>
    <%= form.text_field :topic,
        class: "form-control",
        placeholder: "E.g. Decide Q2 hiring plan" %>
  </div>

  <div class="mb-3">
    <%= form.label :decision_paragraph, "What Is Being Decided", class: "form-label" %>
    <div class="form-text mb-1">One paragraph describing the actual decision the group needs to make.</div>
    <%= form.text_area :decision_paragraph,
        rows: 4, class: "form-control",
        placeholder: "We need to decide whether to…" %>
  </div>

  <div class="row g-3 mb-3">
    <div class="col-md-4">
      <%= form.label :duration_minutes, "Duration (minutes)", class: "form-label" %>
      <%= form.number_field :duration_minutes,
          class: "form-control", min: 5, max: 240,
          value: consultation.duration_minutes || 60 %>
    </div>
    <div class="col-md-8">
      <%= form.label :scheduled_for, "Scheduled For (optional)", class: "form-label" %>
      <%= form.datetime_local_field :scheduled_for, class: "form-control" %>
    </div>
  </div>

  <div class="mb-4">
    <%= form.label :context, "Additional Context (optional)", class: "form-label" %>
    <div class="form-text mb-1">Recent history, prior attempts, known sensitivities. Do not paste real names, personnel issues, or legal matters into this demo.</div>
    <%= form.text_area :context,
        rows: 3, class: "form-control",
        placeholder: "Last quarter we tried X and it stalled because…" %>
  </div>

  <div class="mb-4" data-controller="participants">
    <label class="form-label fw-semibold">Participants</label>
    <div class="form-text mb-2">First name or pseudonym only. At least one participant required.</div>

    <%# Template for Stimulus cloning — index placeholder replaced by controller %>
    <template data-participants-target="template">
      <div class="row g-2 mb-2 participant-row" data-participants-target="row">
        <div class="col-5">
          <input type="text" name="consultation[participants_attributes][PARTICIPANT_INDEX][name]"
                 placeholder="First name or pseudonym"
                 class="form-control form-control-sm">
        </div>
        <div class="col-5">
          <input type="text" name="consultation[participants_attributes][PARTICIPANT_INDEX][role]"
                 placeholder="Role in the room"
                 class="form-control form-control-sm">
        </div>
        <div class="col-2">
          <button type="button" class="btn btn-sm btn-outline-danger w-100"
                  data-action="click->participants#removeParticipant">
            Remove
          </button>
        </div>
      </div>
    </template>

    <%# Existing persisted participant rows %>
    <div data-participants-target="container">
      <%= form.fields_for :participants do |pf| %>
        <%= render "participant_fields", form: pf %>
      <% end %>
    </div>

    <button type="button" class="btn btn-sm btn-outline-secondary mt-1"
            data-action="click->participants#addParticipant">
      + Add Participant
    </button>
  </div>

  <div class="d-flex gap-2">
    <%= form.submit(consultation.persisted? ? "Update Consultation" : "Save and Continue",
        class: "btn btn-primary") %>
    <% if consultation.persisted? %>
      <%= link_to "Cancel", consultation_path(consultation), class: "btn btn-outline-secondary" %>
    <% else %>
      <%= link_to "Cancel", consultations_path, class: "btn btn-outline-secondary" %>
    <% end %>
  </div>
<% end %>
```

---

### 4. `app/views/consultations/new.html.erb`

```erb
<div class="container py-4">
  <div class="row justify-content-center">
    <div class="col-lg-8">
      <h1 class="h3 mb-4">New Consultation</h1>
      <%= render "form", consultation: @consultation %>
    </div>
  </div>
</div>
```

---

### 5. `app/views/consultations/edit.html.erb`

```erb
<div class="container py-4">
  <div class="row justify-content-center">
    <div class="col-lg-8">
      <div class="d-flex justify-content-between align-items-center mb-4">
        <h1 class="h3 mb-0">Edit Consultation</h1>
        <%= link_to "← Back", consultation_path(@consultation), class: "text-muted small" %>
      </div>
      <%= render "form", consultation: @consultation %>
    </div>
  </div>
</div>
```

---

### 6. `app/views/consultations/index.html.erb`

```erb
<div class="container py-4">
  <div class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h3 mb-0">My Consultations</h1>
    <%= link_to "New Consultation", new_consultation_path, class: "btn btn-primary" %>
  </div>

  <%# Sort controls %>
  <div class="mb-4">
    <%= link_to "Most recent",
        consultations_path,
        class: "btn btn-sm #{params[:sort].blank? ? 'btn-secondary' : 'btn-outline-secondary'} me-1" %>
    <%= link_to "Scheduled soonest",
        consultations_path(sort: "soonest"),
        class: "btn btn-sm #{params[:sort] == 'soonest' ? 'btn-secondary' : 'btn-outline-secondary'}" %>
  </div>

  <% if @consultations.any? %>
    <div class="row row-cols-1 row-cols-md-3 g-4">
      <% @consultations.each do |consultation| %>
        <%= render "consultation_card", consultation: consultation %>
      <% end %>
    </div>
  <% else %>
    <div class="row justify-content-center">
      <div class="col-md-6 text-center py-5">
        <h5 class="mb-3">No consultations yet</h5>
        <p class="text-muted mb-4">Plan your first decision-making meeting in under two minutes.</p>
        <%= link_to "New Consultation", new_consultation_path, class: "btn btn-primary" %>
      </div>
    </div>
  <% end %>
</div>
```

---

## Manual Checks

- [ ] `GET /consultations/new` renders the form with two participant rows pre-filled (Stimulus `connect` adds them).
- [ ] Clicking "Add Participant" adds a third row. Clicking again adds a fourth. Each row has its own unique name/role inputs (verify in browser dev tools — field names should have different indices).
- [ ] Clicking "Remove" on a new (unpersisted) row removes it from the DOM.
- [ ] Submitting with valid inputs (topic ≥ 5 chars, decision_paragraph ≥ 20 chars, duration 5–240, at least one participant name and role) creates the consultation and redirects to the show page.
- [ ] Submitting with no participant name/role filled in shows the validation error "At least one participant is required".
- [ ] Submitting with a topic under 5 characters shows the validation error.
- [ ] Submitting with `decision_paragraph` under 20 characters shows the validation error.
- [ ] `GET /consultations/:id/edit` shows existing participants as pre-filled rows.
- [ ] Editing: remove an existing participant (mark for destruction via "Remove" button), save — participant is gone from the database.
- [ ] Editing: add a new participant row and save — new participant persists.
- [ ] `DELETE /consultations/:id` removes the consultation and redirects to the index.
- [ ] Index: "Most recent" and "Scheduled soonest" sort links change the card order correctly.

---

## Acceptance Criteria

- [ ] `participants_controller.js` registered in `controllers/index.js`.
- [ ] `_participant_fields.html.erb` used by `fields_for` for persisted rows.
- [ ] `_form.html.erb` has the Stimulus `data-controller="participants"` wrapper, `<template>` tag with `PARTICIPANT_INDEX` placeholder, and persisted participant rows in the `data-participants-target="container"`.
- [ ] `new.html.erb`, `edit.html.erb`, and `index.html.erb` created.
- [ ] No `onclick`, `addEventListener`, or `<script>` tags anywhere in these views.
