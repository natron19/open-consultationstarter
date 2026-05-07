# Phase 1 — Branding & Configuration

**Builds on:** Open Demo Starter boilerplate is installed and running (`bin/dev` works, seeded admin user exists).
**Reference docs:** [`CLAUDE.md`](../../CLAUDE.md) — env vars, accent color, nav link patterns.
**Goal:** The app reads as ConsultationStarter from first boot — correct name, tagline, accent color, and nav link — before any domain models exist.

---

## Deliverables

### 1. `.env.example` — add/update branding vars

```
APP_NAME=ConsultationStarter Demo
APP_TAGLINE=Describe the decision. Get a meeting plan that produces a real conversation.
APP_DESCRIPTION=An AI-powered meeting planner that organizes any decision-making meeting around the Seven Principles of Consultation. Enter the topic, the decision paragraph, the participants, and the duration. Get back a sharpened purpose statement, success criteria, anonymous pre-meeting questions, in-session facilitator prompts, and a decision record template.
```

Also update your local `.env` with the same values (`.env` is gitignored; `.env.example` is committed).

---

### 2. `app/assets/stylesheets/application.css` — accent color + component classes

Replace the boilerplate `:root` accent variables and add the three component classes below:

```css
:root {
  --accent: #0c4a6e;
  --accent-hover: #075985;
}

.btn-primary {
  --bs-btn-bg: var(--accent);
  --bs-btn-border-color: var(--accent);
  --bs-btn-hover-bg: var(--accent-hover);
  --bs-btn-hover-border-color: var(--accent-hover);
  --bs-btn-active-bg: var(--accent-hover);
  --bs-btn-active-border-color: var(--accent-hover);
  --bs-btn-disabled-bg: var(--accent);
  --bs-btn-disabled-border-color: var(--accent);
}

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

Do not touch other rules in the file.

---

### 3. `app/views/layouts/application.html.erb` — "Consultations" nav link

Add a "Consultations" link for signed-in users inside the navbar, between the brand link and the user dropdown:

```erb
<% if signed_in? %>
  <%= link_to "Consultations", consultations_path, class: "nav-link" %>
<% end %>
```

`consultations_path` does not exist yet — this will raise a routing error until Phase 3 adds the route. That is acceptable; the route helper will resolve once routes are defined.

---

### 4. `app/views/home/index.html.erb` — landing pitch stub

Replace the boilerplate placeholder with a functional landing page. The full implementation with a three-column features row comes in Phase 4. For now, the stub must pass the manual checks below:

```erb
<div class="container py-5">
  <div class="row justify-content-center text-center mb-5">
    <div class="col-lg-8">
      <h1 class="display-5 fw-bold mb-3">
        <%= ENV.fetch("APP_NAME", "ConsultationStarter Demo") %>
      </h1>
      <p class="lead mb-4">
        <%= ENV.fetch("APP_TAGLINE", "") %>
      </p>
      <p class="text-muted mb-4">
        <%= ENV.fetch("APP_DESCRIPTION", "") %>
      </p>
      <% if signed_in? %>
        <%= link_to "Plan Your Next Decision", new_consultation_path, class: "btn btn-primary btn-lg" %>
      <% else %>
        <%= link_to "Get Started", sign_up_path, class: "btn btn-primary btn-lg" %>
      <% end %>
    </div>
  </div>
</div>
```

The `new_consultation_path` helper will resolve in Phase 3. This page skips authentication — confirm `home#index` has `skip_before_action :require_authentication` in the controller (it should already, as the boilerplate home does this).

---

## Manual Checks

- [ ] Boot the app (`bin/dev`). Browser tab / navbar shows "ConsultationStarter Demo", not the old boilerplate name.
- [ ] Home page (`/`) shows the tagline and description text from `.env`.
- [ ] Primary button color is deep ocean blue (`#0c4a6e`) — visually distinct from the boilerplate default.
- [ ] Sign in as `demo@example.com` / `password123` — "Consultations" link appears in the navbar (may produce a routing error if clicked — that is fine until Phase 3).
- [ ] Sign out — "Consultations" link disappears.
- [ ] No hardcoded "ConsultationStarter Demo" string in any view file; all name/tagline/description reads from `ENV.fetch`.

---

## Acceptance Criteria

- [ ] `.env.example` has all three branding vars with the correct values (not placeholders).
- [ ] `application.css` defines `--accent: #0c4a6e` and the three component classes.
- [ ] Navbar "Consultations" link is conditional on `signed_in?`.
- [ ] Home page uses `ENV.fetch` for every piece of branded copy.
