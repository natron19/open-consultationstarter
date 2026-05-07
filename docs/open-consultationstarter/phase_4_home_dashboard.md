# Phase 4 — Home & Dashboard Views

**Builds on:** Phase 3 complete (routes and controllers exist).
**Reference docs:** [`CLAUDE.md`](../../CLAUDE.md) — Bootstrap dark mode, standard page structure, no hardcoded app name. [`docs/turbo-stimulus-patterns.md`](../turbo-stimulus-patterns.md) — Turbo navigation patterns.
**Goal:** The landing page pitch and the dashboard card grid are fully implemented and render correctly.

---

## Deliverables

### 1. `app/views/consultations/_consultation_card.html.erb` (shared partial)

Create this partial first — it is used by both the dashboard and the consultations index.

```erb
<div class="col">
  <%= link_to consultation_path(consultation), class: "text-decoration-none" do %>
    <div class="card h-100 bg-dark border-secondary">
      <div class="card-body">
        <h6 class="card-title text-white fw-semibold mb-1">
          <%= consultation.topic %>
        </h6>
        <p class="text-muted small mb-2">
          <% if consultation.scheduled_for %>
            <%= consultation.scheduled_for.strftime("%b %-d, %Y at %-I:%M %p") %>
          <% else %>
            Not scheduled
          <% end %>
        </p>
        <p class="text-muted small mb-3">
          <%= pluralize(consultation.participants.size, "participant") %>
        </p>
        <% if consultation.consultation_plan.present? %>
          <span class="badge bg-success">Plan generated</span>
        <% else %>
          <span class="badge bg-secondary">Awaiting plan</span>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

---

### 2. `app/views/home/index.html.erb` (full implementation, replaces Phase 1 stub)

```erb
<div class="container py-5">
  <%# Hero %>
  <div class="row justify-content-center text-center mb-5">
    <div class="col-lg-8">
      <h1 class="display-5 fw-bold mb-3">
        <%= ENV.fetch("APP_NAME", "ConsultationStarter Demo") %>
      </h1>
      <p class="lead mb-3">
        <%= ENV.fetch("APP_TAGLINE", "") %>
      </p>
      <p class="text-muted mb-4">
        <%= ENV.fetch("APP_DESCRIPTION", "") %>
      </p>
      <% if signed_in? %>
        <%= link_to "Plan Your Next Decision", new_consultation_path, class: "btn btn-primary btn-lg" %>
      <% else %>
        <%= link_to "Get Started — It's Free", sign_up_path, class: "btn btn-primary btn-lg me-2" %>
        <%= link_to "Sign In", sign_in_path, class: "btn btn-outline-secondary btn-lg" %>
      <% end %>
    </div>
  </div>

  <%# Features row — five plan outputs described in three cards %>
  <div class="row g-4 justify-content-center">
    <div class="col-md-4">
      <div class="card h-100 plan-section-card bg-dark border-secondary">
        <div class="card-body">
          <h6 class="fw-semibold mb-2">Purpose &amp; Success Criteria</h6>
          <p class="text-muted small mb-0">
            A one-sentence, decision-shaped purpose statement the group can commit to before discussion starts, plus three observable success markers to use at close.
          </p>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div class="card h-100 plan-section-card bg-dark border-secondary">
        <div class="card-body">
          <h6 class="fw-semibold mb-2">Pre-Meeting Questions</h6>
          <p class="text-muted small mb-0">
            Three to five anonymous questions mapped to the Seven Principles — sent to participants before the meeting so honest input is captured before bias sets in.
          </p>
        </div>
      </div>
    </div>
    <div class="col-md-4">
      <div class="card h-100 plan-section-card bg-dark border-secondary">
        <div class="card-body">
          <h6 class="fw-semibold mb-2">Facilitator Prompts &amp; Decision Record</h6>
          <p class="text-muted small mb-0">
            Five in-session prompts — one per principle — for the facilitator to use when the conversation needs intervention, plus a decision record template ready to copy.
          </p>
        </div>
      </div>
    </div>
  </div>
</div>
```

---

### 3. `app/views/dashboard/show.html.erb` (replaces boilerplate)

```erb
<div class="container py-4">
  <div class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h3 mb-0">
      Welcome back<% if current_user.respond_to?(:first_name) && current_user.first_name.present? %>, <%= current_user.first_name %><% end %>
    </h1>
    <%= link_to "New Consultation", new_consultation_path, class: "btn btn-primary" %>
  </div>

  <% consultations = current_user.consultations.order(created_at: :desc).limit(6) %>

  <% if consultations.any? %>
    <div class="row row-cols-1 row-cols-md-3 g-4">
      <% consultations.each do |consultation| %>
        <%= render "consultations/consultation_card", consultation: consultation %>
      <% end %>
    </div>

    <% if current_user.consultations.count > 6 %>
      <div class="mt-3 text-end">
        <%= link_to "View all consultations →", consultations_path, class: "text-muted small" %>
      </div>
    <% end %>
  <% else %>
    <div class="row justify-content-center">
      <div class="col-md-6 text-center py-5">
        <h5 class="mb-3">No consultations yet</h5>
        <p class="text-muted mb-4">
          Enter a meeting topic and decision paragraph to get a complete consultation plan in seconds.
        </p>
        <%= link_to "Plan Your Next Decision", new_consultation_path, class: "btn btn-primary" %>
      </div>
    </div>
  <% end %>
</div>
```

**Note:** The `first_name` guard is a defensive check — the boilerplate `User` model may not have a `first_name` column. If it does not, the greeting simply reads "Welcome back" without a name.

---

## Manual Checks

- [ ] `GET /` — home page renders with tagline, description, and the three feature cards with the accent left border.
- [ ] Home page CTA button: signed-out user sees "Get Started"; signed-in user sees "Plan Your Next Decision".
- [ ] `GET /dashboard` — signed-in user sees the empty state with the CTA.
- [ ] After creating a consultation via console (`Consultation.create!(user: User.first, topic: "Test topic long enough", decision_paragraph: "We need to decide something important here with everyone's input.", duration_minutes: 60, participants_attributes: [{ name: "Alice", role: "Lead" }])`), the dashboard shows the card with the "Awaiting plan" badge.
- [ ] After associating a plan with that consultation, the badge changes to "Plan generated".
- [ ] Card is a clickable link to the consultation show page.

---

## Acceptance Criteria

- [ ] `_consultation_card` partial renders topic, scheduled date or "Not scheduled", participant count, and correct status badge.
- [ ] Home page uses `ENV.fetch` for all branded copy — no hardcoded strings.
- [ ] Dashboard empty state renders when user has no consultations.
- [ ] Dashboard card grid renders up to 6 most-recent consultations.
- [ ] "View all consultations →" link appears when user has more than 6.
