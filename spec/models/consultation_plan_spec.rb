require "rails_helper"

RSpec.describe ConsultationPlan, type: :model do
  describe "validations" do
    it "is valid with all required attributes" do
      expect(build(:consultation_plan)).to be_valid
    end

    %i[purpose_statement success_criteria pre_meeting_questions
       facilitator_prompts decision_record_template gemini_raw].each do |field|
      it "requires #{field}" do
        expect(build(:consultation_plan, field => nil)).not_to be_valid
      end
    end

    it "enforces one plan per consultation" do
      consultation = create(:consultation)
      create(:consultation_plan, consultation: consultation)
      duplicate = build(:consultation_plan, consultation: consultation)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "associations" do
    it "belongs to a consultation" do
      plan = build(:consultation_plan)
      expect(plan.consultation).to be_a(Consultation)
    end
  end

  describe "#success_criteria_array" do
    it "parses valid JSON into an array" do
      plan = build(:consultation_plan, success_criteria: ["A", "B", "C"].to_json)
      expect(plan.success_criteria_array).to eq(["A", "B", "C"])
    end

    it "returns [] for malformed JSON" do
      plan = build(:consultation_plan, success_criteria: "not json")
      expect(plan.success_criteria_array).to eq([])
    end

    it "returns [] for nil" do
      plan = build(:consultation_plan, success_criteria: nil)
      expect(plan.success_criteria_array).to eq([])
    end
  end

  describe "#pre_meeting_questions_array" do
    it "parses valid JSON into an array" do
      data = [{ "question" => "Q?", "principle" => "Search for Truth" }]
      plan = build(:consultation_plan, pre_meeting_questions: data.to_json)
      expect(plan.pre_meeting_questions_array).to eq(data)
    end

    it "returns [] for malformed JSON" do
      plan = build(:consultation_plan, pre_meeting_questions: "{bad}")
      expect(plan.pre_meeting_questions_array).to eq([])
    end

    it "returns [] for nil" do
      plan = build(:consultation_plan, pre_meeting_questions: nil)
      expect(plan.pre_meeting_questions_array).to eq([])
    end
  end

  describe "#facilitator_prompts_array" do
    it "parses valid JSON into an array" do
      data = [{ "order" => 1, "principle" => "Spirit of Service", "prompt" => "P", "when_to_use" => "W" }]
      plan = build(:consultation_plan, facilitator_prompts: data.to_json)
      expect(plan.facilitator_prompts_array).to eq(data)
    end

    it "returns [] for malformed JSON" do
      plan = build(:consultation_plan, facilitator_prompts: "broken")
      expect(plan.facilitator_prompts_array).to eq([])
    end

    it "returns [] for nil" do
      plan = build(:consultation_plan, facilitator_prompts: nil)
      expect(plan.facilitator_prompts_array).to eq([])
    end
  end
end
