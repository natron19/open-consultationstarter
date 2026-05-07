require "rails_helper"

RSpec.describe Participant, type: :model do
  describe "validations" do
    it "is valid with name and role" do
      expect(build(:participant)).to be_valid
    end

    it "requires name" do
      expect(build(:participant, name: nil)).not_to be_valid
    end

    it "requires name to be at most 80 characters" do
      expect(build(:participant, name: "a" * 81)).not_to be_valid
    end

    it "requires role" do
      expect(build(:participant, role: nil)).not_to be_valid
    end

    it "requires role to be at most 80 characters" do
      expect(build(:participant, role: "a" * 81)).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a consultation" do
      participant = build(:participant)
      expect(participant.consultation).to be_a(Consultation)
    end
  end

  describe "dependent destroy" do
    it "is destroyed when its consultation is destroyed" do
      consultation = create(:consultation)
      participant_id = consultation.participants.first.id
      consultation.destroy
      expect(Participant.find_by(id: participant_id)).to be_nil
    end
  end
end
