# Phase 8 — Request Tests

**Builds on:** All prior phases complete (models, controllers, views, AI integration, and seed data all working). Model specs from Phase 2 already pass.
**Reference docs:** [`docs/testing.md`](../testing.md) — RSpec factories, request spec patterns, Gemini stubs. [`CLAUDE.md`](../../CLAUDE.md) — never call real Gemini in tests.
**Goal:** All HTTP flows for consultations and plan generation are covered by request specs: authentication enforcement, ownership scoping (404 not 403), CRUD operations, Gemini error handling, and Turbo Stream responses.

---

## Setup Reminder

Every spec that touches `GeminiService` must stub it — no real API calls in tests. The boilerplate's `spec/support/gemini_test_double.rb` provides helpers. Ensure your `spec/rails_helper.rb` includes:

```ruby
require "support/gemini_test_double"
```

And your `spec/support/authentication_helpers.rb` provides:

```ruby
def sign_in_as(user)
  post sign_in_path, params: { email: user.email, password: "password123" }
end
```

---

## `spec/requests/consultations_spec.rb`

```ruby
require "rails_helper"

RSpec.describe "Consultations", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let!(:consultation) { create(:consultation, user: user) }

  describe "GET /consultations" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        get consultations_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "returns 200" do
        get consultations_path
        expect(response).to have_http_status(:ok)
      end

      it "shows only the signed-in user's consultations" do
        other_consultation = create(:consultation, user: other)
        get consultations_path
        expect(response.body).to include(consultation.topic)
        expect(response.body).not_to include(other_consultation.topic)
      end
    end
  end

  describe "GET /consultations/new" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        get new_consultation_path
        expect(response).to redirect_to(sign_in_path)
      end
    end

    it "returns 200 when signed in" do
      sign_in_as(user)
      get new_consultation_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /consultations" do
    let(:valid_params) do
      {
        consultation: {
          topic: "A topic long enough",
          decision_paragraph: "We need to decide something important that requires group input.",
          duration_minutes: 60,
          participants_attributes: { "0" => { name: "Alice", role: "Lead" } }
        }
      }
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        post consultations_path, params: valid_params
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "creates the consultation and redirects to show" do
        expect {
          post consultations_path, params: valid_params
        }.to change(Consultation, :count).by(1)
        expect(response).to redirect_to(consultation_path(Consultation.last))
      end

      it "creates the nested participant" do
        expect {
          post consultations_path, params: valid_params
        }.to change(Participant, :count).by(1)
      end

      it "re-renders the form with 422 when no participants provided" do
        params = valid_params.deep_merge(consultation: { participants_attributes: {} })
        post consultations_path, params: params
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("At least one participant is required")
      end

      it "re-renders the form with 422 when decision_paragraph is too short" do
        params = valid_params.deep_merge(consultation: { decision_paragraph: "Too short" })
        post consultations_path, params: params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /consultations/:id" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        get consultation_path(consultation)
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in as owner" do
      it "returns 200" do
        sign_in_as(user)
        get consultation_path(consultation)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in as a different user" do
      it "returns 404" do
        sign_in_as(other)
        get consultation_path(consultation)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /consultations/:id" do
    before { sign_in_as(user) }

    it "updates the topic" do
      patch consultation_path(consultation), params: {
        consultation: {
          topic: "Updated topic that is long enough",
          decision_paragraph: consultation.decision_paragraph,
          duration_minutes: consultation.duration_minutes,
          participants_attributes: { "0" => { id: consultation.participants.first.id, name: "Alice", role: "Lead" } }
        }
      }
      expect(consultation.reload.topic).to eq("Updated topic that is long enough")
      expect(response).to redirect_to(consultation_path(consultation))
    end

    it "returns 404 for another user's consultation" do
      sign_in_as(other)
      patch consultation_path(consultation), params: {
        consultation: { topic: "Hacked" }
      }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /consultations/:id" do
    before { sign_in_as(user) }

    it "destroys the consultation and its participants" do
      participant = consultation.participants.first
      expect {
        delete consultation_path(consultation)
      }.to change(Consultation, :count).by(-1)
        .and change(Participant, :count).by(-1)
      expect(response).to redirect_to(consultations_path)
    end

    it "returns 404 for another user's consultation" do
      sign_in_as(other)
      delete consultation_path(consultation)
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

---

## `spec/requests/consultation_plans_spec.rb`

```ruby
require "rails_helper"

RSpec.describe "ConsultationPlans", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }
  let!(:consultation) { create(:consultation, user: user) }

  let(:valid_gemini_response) do
    {
      "purpose_statement" => "Decide X with a clear trigger.",
      "success_criteria" => ["Criterion 1", "Criterion 2", "Criterion 3"],
      "pre_meeting_questions" => [
        { "question" => "Q1?", "principle" => "Search for Truth" },
        { "question" => "Q2?", "principle" => "Detachment from Personal Views" },
        { "question" => "Q3?", "principle" => "Frankness with Courtesy" }
      ],
      "facilitator_prompts" => [
        { "order" => 1, "principle" => "Spirit of Service",       "prompt" => "P1", "when_to_use" => "W1" },
        { "order" => 2, "principle" => "Equality of Voice",       "prompt" => "P2", "when_to_use" => "W2" },
        { "order" => 3, "principle" => "Frankness with Courtesy", "prompt" => "P3", "when_to_use" => "W3" },
        { "order" => 4, "principle" => "Search for Truth",        "prompt" => "P4", "when_to_use" => "W4" },
        { "order" => 5, "principle" => "Unity in Action",         "prompt" => "P5", "when_to_use" => "W5" }
      ],
      "decision_record_template" => "## Decision\n[placeholder]"
    }.to_json
  end

  describe "POST /consultations/:consultation_id/plan" do
    context "when unauthenticated" do
      it "redirects to sign in" do
        post consultation_plan_path(consultation)
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in as a different user" do
      it "returns 404" do
        sign_in_as(other)
        post consultation_plan_path(consultation)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as owner" do
      before do
        sign_in_as(user)
        allow(GeminiService).to receive(:generate).and_return(valid_gemini_response)
      end

      it "calls GeminiService with the correct template name" do
        post consultation_plan_path(consultation)
        expect(GeminiService).to have_received(:generate)
          .with(hash_including(template: "consultationstarter_meeting_plan_v1"))
      end

      it "calls GeminiService with all five expected variable keys" do
        post consultation_plan_path(consultation)
        expect(GeminiService).to have_received(:generate).with(
          hash_including(
            variables: hash_including(
              :topic, :decision_paragraph, :duration_minutes, :context, :participants_list
            )
          )
        )
      end

      it "creates a ConsultationPlan with all five fields and gemini_raw populated" do
        expect {
          post consultation_plan_path(consultation)
        }.to change(ConsultationPlan, :count).by(1)

        plan = consultation.reload.consultation_plan
        expect(plan.purpose_statement).to eq("Decide X with a clear trigger.")
        expect(plan.success_criteria_array).to eq(["Criterion 1", "Criterion 2", "Criterion 3"])
        expect(plan.pre_meeting_questions_array).to be_an(Array)
        expect(plan.facilitator_prompts_array).to be_an(Array)
        expect(plan.decision_record_template).to be_present
        expect(plan.gemini_raw).to eq(valid_gemini_response)
      end

      it "creates exactly one LlmRequest record" do
        expect {
          post consultation_plan_path(consultation)
        }.to change(LlmRequest, :count).by(1)
      end

      it "responds with Turbo Stream content type for Turbo requests" do
        post consultation_plan_path(consultation),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end

      it "replaces an existing plan without creating a duplicate" do
        create(:consultation_plan, consultation: consultation)
        expect {
          post consultation_plan_path(consultation)
        }.not_to change(ConsultationPlan, :count)
      end

      context "when Gemini raises BudgetExceededError" do
        before do
          allow(GeminiService).to receive(:generate)
            .and_raise(GeminiService::BudgetExceededError, "limit reached")
        end

        it "does not create a plan" do
          expect {
            post consultation_plan_path(consultation)
          }.not_to change(ConsultationPlan, :count)
        end

        it "returns a Turbo Stream with error content" do
          post consultation_plan_path(consultation),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response.content_type).to include("text/vnd.turbo-stream.html")
        end
      end

      context "when Gemini raises TimeoutError" do
        before do
          allow(GeminiService).to receive(:generate)
            .and_raise(GeminiService::TimeoutError, "timeout")
        end

        it "does not create a plan" do
          expect {
            post consultation_plan_path(consultation)
          }.not_to change(ConsultationPlan, :count)
        end
      end

      context "when Gemini raises GatekeeperError" do
        before do
          allow(GeminiService).to receive(:generate)
            .and_raise(GeminiService::GatekeeperError, "blocked")
        end

        it "does not create a plan" do
          expect {
            post consultation_plan_path(consultation)
          }.not_to change(ConsultationPlan, :count)
        end
      end

      context "when Gemini returns malformed JSON" do
        before do
          allow(GeminiService).to receive(:generate)
            .and_return("this is not json at all {{{")
        end

        it "does not create a ConsultationPlan record" do
          expect {
            post consultation_plan_path(consultation)
          }.not_to change(ConsultationPlan, :count)
        end

        it "saves gemini_raw on an existing plan" do
          existing = create(:consultation_plan, consultation: consultation)
          post consultation_plan_path(consultation)
          expect(existing.reload.gemini_raw).to eq("this is not json at all {{{")
        end

        it "returns a Turbo Stream parse error partial" do
          post consultation_plan_path(consultation),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response.content_type).to include("text/vnd.turbo-stream.html")
        end
      end
    end
  end

  describe "DELETE /consultations/:consultation_id/plan" do
    let!(:plan) { create(:consultation_plan, consultation: consultation) }

    before { sign_in_as(user) }

    it "removes the plan but leaves the consultation intact" do
      expect {
        delete consultation_plan_path(consultation)
      }.to change(ConsultationPlan, :count).by(-1)
      expect(Consultation.find(consultation.id)).to be_present
    end

    it "returns 404 for another user's consultation" do
      sign_in_as(other)
      delete consultation_plan_path(consultation)
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

---

## Manual RSpec Checks

- [ ] `bundle exec rspec spec/requests/consultations_spec.rb` — all pass.
- [ ] `bundle exec rspec spec/requests/consultation_plans_spec.rb` — all pass.
- [ ] `bundle exec rspec` — full suite (models + requests) passes with zero real Gemini API calls made.

---

## Acceptance Criteria

- [ ] `spec/requests/consultations_spec.rb` created and passing.
- [ ] `spec/requests/consultation_plans_spec.rb` created and passing.
- [ ] All specs stub `GeminiService.generate` — no real API calls.
- [ ] Access control: unauthenticated requests redirect to sign in; cross-user requests return 404 (not 403) for all consultation and plan routes.
- [ ] `LlmRequest` count assertion confirms the boilerplate logging fires on the plan-generation path.
- [ ] Full suite passes: `bundle exec rspec`.
