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
