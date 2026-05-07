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
