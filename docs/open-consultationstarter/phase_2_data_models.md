# Phase 2 — Data Models & Migrations

**Builds on:** Phase 1 complete (branding set, app boots).
**Reference docs:** [`CLAUDE.md`](../../CLAUDE.md) — database conventions (UUID PKs, null: false timestamps, indexed columns). [`docs/testing.md`](../testing.md) — RSpec factories and model specs.
**Goal:** Database schema for the three domain models exists and is correct; models validate and associate correctly; model specs cover all validations, associations, and reader methods.

---

## Deliverables

### 1. Migration: `create_consultations`

```ruby
class CreateConsultations < ActiveRecord::Migration[8.1]
  def change
    create_table :consultations, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string  :topic,              null: false
      t.text    :decision_paragraph, null: false
      t.integer :duration_minutes,   null: false, default: 60
      t.text    :context
      t.datetime :scheduled_for
      t.timestamps null: false
    end
    add_index :consultations, :created_at
  end
end
```

---

### 2. Migration: `create_participants`

```ruby
class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants, id: :uuid do |t|
      t.references :consultation, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :role, null: false
      t.timestamps null: false
    end
  end
end
```

---

### 3. Migration: `create_consultation_plans`

```ruby
class CreateConsultationPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :consultation_plans, id: :uuid do |t|
      t.references :consultation, null: false, foreign_key: true, type: :uuid,
                   index: { unique: true }
      t.text :purpose_statement
      t.text :success_criteria
      t.text :pre_meeting_questions
      t.text :facilitator_prompts
      t.text :decision_record_template
      t.text :gemini_raw
      t.timestamps null: false
    end
  end
end
```

Run `rails db:migrate` after creating all three migrations.

---

### 4. `app/models/consultation.rb`

```ruby
class Consultation < ApplicationRecord
  belongs_to :user
  has_many :participants, dependent: :destroy
  has_one :consultation_plan, dependent: :destroy
  accepts_nested_attributes_for :participants, allow_destroy: true, reject_if: :all_blank

  validates :topic, presence: true, length: { minimum: 5, maximum: 200 }
  validates :decision_paragraph, presence: true, length: { minimum: 20, maximum: 2000 }
  validates :duration_minutes, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 5,
                            less_than_or_equal_to: 240 }
  validates :context, length: { maximum: 2000 }, allow_blank: true
  validate :at_least_one_participant

  private

  def at_least_one_participant
    if participants.reject(&:marked_for_destruction?).empty?
      errors.add(:base, "At least one participant is required")
    end
  end
end
```

---

### 5. `app/models/participant.rb`

```ruby
class Participant < ApplicationRecord
  belongs_to :consultation

  validates :name, presence: true, length: { minimum: 1, maximum: 80 }
  validates :role, presence: true, length: { minimum: 1, maximum: 80 }
end
```

---

### 6. `app/models/consultation_plan.rb`

```ruby
class ConsultationPlan < ApplicationRecord
  belongs_to :consultation
  has_one :user, through: :consultation

  validates :purpose_statement,        presence: true
  validates :success_criteria,         presence: true
  validates :pre_meeting_questions,    presence: true
  validates :facilitator_prompts,      presence: true
  validates :decision_record_template, presence: true
  validates :gemini_raw,               presence: true

  def success_criteria_array
    JSON.parse(success_criteria)
  rescue JSON::ParserError, TypeError
    []
  end

  def pre_meeting_questions_array
    JSON.parse(pre_meeting_questions)
  rescue JSON::ParserError, TypeError
    []
  end

  def facilitator_prompts_array
    JSON.parse(facilitator_prompts)
  rescue JSON::ParserError, TypeError
    []
  end
end
```

---

## RSpec

### `spec/factories/consultations.rb`

```ruby
FactoryBot.define do
  factory :consultation do
    user
    sequence(:topic) { |n| "Consultation topic #{n} that is long enough" }
    decision_paragraph { "We need to decide something important that requires careful thought and group input from all members." }
    duration_minutes { 60 }
    context { nil }
    scheduled_for { nil }

    after(:build) do |consultation|
      if consultation.participants.empty?
        consultation.participants << build(:participant, consultation: consultation)
      end
    end

    trait :with_plan do
      after(:create) do |consultation|
        create(:consultation_plan, consultation: consultation)
      end
    end

    trait :scheduled do
      scheduled_for { 2.days.from_now }
    end
  end
end
```

### `spec/factories/participants.rb`

```ruby
FactoryBot.define do
  factory :participant do
    consultation
    sequence(:name) { |n| "Participant #{n}" }
    role { "Team Member" }
  end
end
```

### `spec/factories/consultation_plans.rb`

```ruby
FactoryBot.define do
  factory :consultation_plan do
    consultation
    purpose_statement       { "Decide whether to do X, with a clear trigger for revisiting." }
    success_criteria        { ["Criterion 1", "Criterion 2", "Criterion 3"].to_json }
    pre_meeting_questions   { [{ "question" => "Q1?", "principle" => "Search for Truth" }].to_json }
    facilitator_prompts     { [{ "order" => 1, "principle" => "Spirit of Service", "prompt" => "Open prompt.", "when_to_use" => "At the start." }].to_json }
    decision_record_template { "## Decision\n[placeholder]" }
    gemini_raw              { '{"purpose_statement":"Test","success_criteria":["c1","c2","c3"],"pre_meeting_questions":[{"question":"Q?","principle":"Search for Truth"}],"facilitator_prompts":[{"order":1,"principle":"Spirit of Service","prompt":"P","when_to_use":"W"}],"decision_record_template":"## Decision\n[placeholder]"}' }
  end
end
```

---

### `spec/models/consultation_spec.rb`

```ruby
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
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:participants) }
    it { is_expected.to have_one(:consultation_plan) }
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
```

---

### `spec/models/participant_spec.rb`

```ruby
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
    it { is_expected.to belong_to(:consultation) }
  end

  describe "dependent destroy" do
    it "is destroyed when its consultation is destroyed" do
      participant = create(:participant)
      consultation = participant.consultation
      consultation.destroy
      expect(Participant.find_by(id: participant.id)).to be_nil
    end
  end
end
```

---

### `spec/models/consultation_plan_spec.rb`

```ruby
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
    it { is_expected.to belong_to(:consultation) }
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
```

---

## Manual Checks

- [ ] `rails db:migrate` completes without errors.
- [ ] `rails db:schema:dump` — all three tables appear in `db/schema.rb` with correct column types.
- [ ] Rails console: `Consultation.new.valid?` → `false`.
- [ ] Rails console: create a consultation with one participant and save — no errors.
- [ ] Rails console: `ConsultationPlan.new(consultation: Consultation.last).valid?` → `false` (missing fields).

## RSpec Checks

- [ ] `bundle exec rspec spec/models/` — all pass, zero actual API calls.
- [ ] All three factory definitions produce valid records with `FactoryBot.create(:<name>)` in a spec context.

---

## Acceptance Criteria

- [ ] Three migrations applied cleanly; schema is correct.
- [ ] Three model files created with all validations, associations, and reader methods.
- [ ] Three factory files created.
- [ ] Three model spec files created and passing.
