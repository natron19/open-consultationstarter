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
        expect(response).to redirect_to(consultation_path(Consultation.order(created_at: :desc).first))
      end

      it "creates the nested participant" do
        expect {
          post consultations_path, params: valid_params
        }.to change(Participant, :count).by(1)
      end

      it "re-renders the form with 422 when no participants provided" do
        params = { consultation: valid_params[:consultation].merge(participants_attributes: {}) }
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
