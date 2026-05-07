# ConsultationStarter Demo — Build Tasks

Phased implementation plan. Each phase is a self-contained document AI can pull into context and work through independently.

**Spec:** [`ConsultationStarter_Demo_Spec_v1.md`](ConsultationStarter_Demo_Spec_v1.md)
**Legend:** `[ ]` not started · `[~]` in progress · `[x]` complete

---

## Phases

| # | Phase | File | Status |
|---|-------|------|--------|
| 1 | Branding & Configuration | [`phase_1_branding.md`](phase_1_branding.md) | `[x]` |
| 2 | Data Models & Migrations + Model Specs | [`phase_2_data_models.md`](phase_2_data_models.md) | `[x]` |
| 3 | Routes & Controllers | [`phase_3_routes_controllers.md`](phase_3_routes_controllers.md) | `[x]` |
| 4 | Home & Dashboard Views | [`phase_4_home_dashboard.md`](phase_4_home_dashboard.md) | `[x]` |
| 5 | Consultations List & Form Views | [`phase_5_consultations_views.md`](phase_5_consultations_views.md) | `[x]` |
| 6 | Consultation Show Page & Plan Views | [`phase_6_show_plan_views.md`](phase_6_show_plan_views.md) | `[x]` |
| 7 | AI Template, Gemini Integration & Seed Data | [`phase_7_ai_seed.md`](phase_7_ai_seed.md) | `[x]` |
| 8 | Request Tests | [`phase_8_request_tests.md`](phase_8_request_tests.md) | `[x]` |
| 9 | README, Final Cleanup & Security Check | [`phase_9_readme_security.md`](phase_9_readme_security.md) | `[x]` |

---

## Phase Summaries

**Phase 1 — Branding & Configuration**
App reads as ConsultationStarter from first boot. Updates `.env.example`, accent color (`#0c4a6e`), navbar "Consultations" link, and the home page stub. No domain models yet.
_Manual checks only._

**Phase 2 — Data Models & Migrations + Model Specs**
Three migrations (`consultations`, `participants`, `consultation_plans`), three model files with all validations/associations/reader methods, three factory files, and three model spec files. Model specs run and pass before moving to Phase 3.
_Includes: RSpec model specs for all three models._

**Phase 3 — Routes & Controllers**
Adds the nine consultation routes and both controllers: `ConsultationsController` (full CRUD scoped to `current_user`) and `ConsultationPlansController` (stub `create`, full `destroy`). The Gemini call in `create` is completed in Phase 7.
_Manual checks only._

**Phase 4 — Home & Dashboard Views**
Full landing page pitch with three-column feature cards, the `_consultation_card` shared partial, and the dashboard card grid with empty state.
_Manual checks only._

**Phase 5 — Consultations List & Form Views**
The `participants_controller.js` Stimulus controller for dynamic add/remove rows, the participant fields partial, the full form partial with nested attributes, and the `new`, `edit`, and `index` views.
_Manual checks only._

**Phase 6 — Consultation Show Page & Plan Views**
`clipboard_controller.js`, `principles_checklist_controller.js`, the seven-principles sidebar partial (with localStorage persistence), the `_plan.html.erb` partial rendering all five sections, and the show page with Turbo Frame `plan-region` and mobile offcanvas sidebar.
_Manual checks only._

**Phase 7 — AI Template, Gemini Integration & Seed Data**
Seed prompt files, `db/seeds.rb` extension (AI template + sample consultation with pre-generated plan), and the complete `ConsultationPlansController#create` action with all Gemini error handling and Turbo Stream responses.
_Manual checks: live Gemini call, seed walkthrough, admin template test panel._

**Phase 8 — Request Tests**
Full request specs for `ConsultationsController` and `ConsultationPlansController`: auth enforcement, ownership scoping (404 not 403), CRUD operations, Gemini stub error scenarios, Turbo Stream content type, and LlmRequest logging assertion.
_Includes: RSpec request specs for both controllers._

**Phase 9 — README, Final Cleanup & Security Check**
README updated with ConsultationStarter content. Cleanup checklist (no pry, no hardcoded strings, no orphaned routes). Full RSpec suite run. Pre-publish security check prompt (from `docs/prompts/pre-publish-security-check.md`) run and all findings resolved. Full end-to-end human walkthrough.
_Includes: security check + full walkthrough._

---

## Dependency Order

```
Phase 1 → Phase 2 → Phase 3 → Phase 4
                              ↓
                         Phase 5 → Phase 6 → Phase 7 → Phase 8 → Phase 9
```

Phases 4–7 can proceed in order once Phase 3 is complete. Phase 8 requires Phases 2–7 complete (needs models, controllers, views, and Gemini integration all in place to test). Phase 9 requires Phase 8 complete.

---

## Implementation Notes

### Model: `gemini-2.0-flash` vs `gemini-2.5-flash`
The spec (Section 7) specifies `gemini-2.0-flash`. Per `docs/ai-templates.md`, that model returns 404 on the v1beta endpoint for new API keys. Use `gemini-2.5-flash` in all seeds and defaults.

### Partial naming: `shared/_ai_error` vs `shared/_gemini_error`
The spec references `shared/_gemini_error` in Section 5, but the boilerplate partial is `shared/_ai_error`. Use `shared/_ai_error` throughout.

### Turbo Stream: always `update()` not `replace()`
Per CLAUDE.md: all Turbo Stream operations on `plan-region` must use `turbo_stream.update`, never `turbo_stream.replace`. `replace()` destroys DOM elements and breaks Stimulus bindings after the first use.

### Consultation scoping
All lookups use `current_user.consultations.find(params[:id])`. This raises `ActiveRecord::RecordNotFound` for another user's record, which Rails renders as 404 — the correct access-control behavior.

### Turbo Stream block syntax trap
`turbo_stream.update("id") do ... end` — the `do...end` block binds to the outer `render` call, not to `update`. Result: `update` receives no block and sends an empty stream, wiping the frame. Always use the keyword form: `turbo_stream.update("id", partial: "...", locals: {...})`.

### Gemini JSON extraction
Gemini 2.5 Flash wraps JSON output in markdown code fences even when instructed not to. Regex fence-stripping (`\A```...`) fails when there is preamble text or `\r\n` line endings. Use `result[result.index("{")..result.rindex("}")]` to extract the JSON object directly.

### Seeds: participants must be built before save
`find_or_create_by!` on Consultation saves immediately, before participants are added in the next step. The `at_least_one_participant` validation fires and aborts the seed. Fix: use `find_by` + `new` + `participants.build` + `save!` so participants exist in memory before the first save.

### Gemini timeout
`gemini-2.5-flash` with the full meeting plan prompt consistently takes 14–18 seconds. The default `AI_GLOBAL_TIMEOUT_SECONDS=15` is too tight. Set to `30` in `.env` and `.env.example`.
