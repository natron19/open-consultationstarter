# Phase 3 — Routes & Controllers

**Builds on:** Phase 2 complete (models and migrations applied).
**Reference docs:** [`CLAUDE.md`](../../CLAUDE.md) — auth patterns, 404-not-403 for access control. [`docs/ai-guardrails.md`](../ai-guardrails.md) — error classes from GeminiService.
**Goal:** All nine consultation routes exist; `ConsultationsController` handles full CRUD scoped to `current_user`; `ConsultationPlansController` has its structure in place (the Gemini call is implemented in Phase 7).

---

## Deliverables

### 1. `config/routes.rb` — add consultation routes

```ruby
resources :consultations do
  resource :plan, controller: "consultation_plans", only: [:create, :destroy]
end
```

This produces:

| Verb   | Path                                  | Controller#Action              |
|--------|---------------------------------------|--------------------------------|
| GET    | `/consultations`                      | `consultations#index`          |
| GET    | `/consultations/new`                  | `consultations#new`            |
| POST   | `/consultations`                      | `consultations#create`         |
| GET    | `/consultations/:id`                  | `consultations#show`           |
| GET    | `/consultations/:id/edit`             | `consultations#edit`           |
| PATCH  | `/consultations/:id`                  | `consultations#update`         |
| DELETE | `/consultations/:id`                  | `consultations#destroy`        |
| POST   | `/consultations/:consultation_id/plan`| `consultation_plans#create`    |
| DELETE | `/consultations/:consultation_id/plan`| `consultation_plans#destroy`   |

---

### 2. `app/controllers/consultations_controller.rb`

```ruby
class ConsultationsController < ApplicationController
  before_action :require_authentication
  before_action :set_consultation, only: [:show, :edit, :update, :destroy]

  def index
    @consultations = if params[:sort] == "soonest"
      current_user.consultations.order("scheduled_for ASC NULLS LAST")
    else
      current_user.consultations.order(created_at: :desc)
    end
  end

  def new
    @consultation = current_user.consultations.build
    2.times { @consultation.participants.build }
  end

  def create
    @consultation = current_user.consultations.build(consultation_params)
    if @consultation.save
      redirect_to consultation_path(@consultation), notice: "Consultation saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @plan = @consultation.consultation_plan
  end

  def edit
  end

  def update
    if @consultation.update(consultation_params)
      redirect_to consultation_path(@consultation), notice: "Consultation updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @consultation.destroy
    redirect_to consultations_path, notice: "Consultation deleted."
  end

  private

  def set_consultation
    @consultation = current_user.consultations.find(params[:id])
  end

  def consultation_params
    params.require(:consultation).permit(
      :topic, :decision_paragraph, :duration_minutes,
      :context, :scheduled_for,
      participants_attributes: [:id, :name, :role, :_destroy]
    )
  end
end
```

**Key security rule:** `set_consultation` uses `current_user.consultations.find(...)`. If `params[:id]` belongs to another user, `find` raises `ActiveRecord::RecordNotFound`, which Rails renders as 404 — matching the boilerplate's access-control pattern. Never look up by bare `Consultation.find(params[:id])`.

---

### 3. `app/controllers/consultation_plans_controller.rb`

Create the controller shell. The `create` action body is completed in Phase 7 once the AI template exists. For now, create a stub that responds correctly to the route and holds the right structure:

```ruby
class ConsultationPlansController < ApplicationController
  before_action :require_authentication
  before_action :set_consultation

  def create
    # Full Gemini integration implemented in Phase 7.
    # Stub: redirect to show page so routes work during development.
    redirect_to consultation_path(@consultation), notice: "Plan generation coming in Phase 7."
  end

  def destroy
    plan = @consultation.consultation_plan
    plan&.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("plan-region") do
          render partial: "consultations/no_plan_cta", locals: { consultation: @consultation }
        end
      end
      format.html { redirect_to consultation_path(@consultation), notice: "Plan discarded." }
    end
  end

  private

  def set_consultation
    @consultation = current_user.consultations.find(params[:consultation_id])
  end
end
```

---

## Manual Checks

- [ ] `rails routes | grep consultation` — confirm all 9 routes are listed.
- [ ] Unauthenticated `GET /consultations` redirects to `/sign_in`.
- [ ] Signed-in user visits `/consultations` — renders (even if the view is a blank template for now).
- [ ] Signed-in user visits `/consultations/new` — renders (blank template is fine).
- [ ] The navbar "Consultations" link no longer throws a routing error.

---

## Acceptance Criteria

- [ ] `config/routes.rb` includes the nested consultation/plan routes.
- [ ] `ConsultationsController` has all 7 CRUD actions, `before_action :require_authentication`, and scoped `set_consultation`.
- [ ] `ConsultationPlansController` has `create` (stub) and `destroy`, both scoped to `current_user`.
- [ ] No bare `Consultation.find` anywhere — all lookups are scoped through `current_user.consultations`.
