require "rails_helper"

RSpec.describe Consultation, type: :model do
  describe "validations" do
    it "is valid with all required attributes and a participant" do
      expect(build(:consultation)).to be_valid
    end

    it "requires topic" do
      expect(build(:consultation, topic: nil)).not_to be_valid
    end

    it "requires topic to be at least 5 characters" do
      expect(build(:consultation, topic: "abc")).not_to be_valid
    end

    it "requires topic to be at most 200 characters" do
      expect(build(:consultation, topic: "a" * 201)).not_to be_valid
    end

    it "requires decision_paragraph" do
      expect(build(:consultation, decision_paragraph: nil)).not_to be_valid
    end

    it "requires decision_paragraph to be at least 20 characters" do
      expect(build(:consultation, decision_paragraph: "Too short")).not_to be_valid
    end

    it "requires decision_paragraph to be at most 2000 characters" do
      expect(build(:consultation, decision_paragraph: "a" * 2001)).not_to be_valid
    end

    it "requires duration_minutes" do
      expect(build(:consultation, duration_minutes: nil)).not_to be_valid
    end

    it "requires duration_minutes to be at least 5" do
      expect(build(:consultation, duration_minutes: 4)).not_to be_valid
    end

    it "requires duration_minutes to be at most 240" do
      expect(build(:consultation, duration_minutes: 241)).not_to be_valid
    end

    it "allows context to be blank" do
      expect(build(:consultation, context: nil)).to be_valid
    end

    it "requires context to be at most 2000 characters when present" do
      expect(build(:consultation, context: "a" * 2001)).not_to be_valid
    end

    it "requires at least one participant" do
      consultation = build(:consultation)
      consultation.participants.clear
      expect(consultation).not_to be_valid
      expect(consultation.errors[:base]).to include("At least one participant is required")
    end

    it "is invalid when all participants are marked for destruction" do
      consultation = create(:consultation)
      consultation.participants.each { |p| p.mark_for_destruction }
      expect(consultation).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a user" do
      consultation = build(:consultation)
      expect(consultation.user).to be_a(User)
    end

    it "has many participants" do
      consultation = create(:consultation)
      expect(consultation.participants).to be_present
    end

    it "can have a consultation plan" do
      consultation = create(:consultation, :with_plan)
      expect(consultation.consultation_plan).to be_a(ConsultationPlan)
    end
  end

  describe "dependent destroy" do
    it "destroys participants when consultation is destroyed" do
      consultation = create(:consultation)
      participant_id = consultation.participants.first.id
      consultation.destroy
      expect(Participant.find_by(id: participant_id)).to be_nil
    end

    it "destroys consultation_plan when consultation is destroyed" do
      consultation = create(:consultation, :with_plan)
      plan_id = consultation.consultation_plan.id
      consultation.destroy
      expect(ConsultationPlan.find_by(id: plan_id)).to be_nil
    end
  end
end
