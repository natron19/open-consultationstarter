FactoryBot.define do
  factory :participant do
    consultation
    sequence(:name) { |n| "Participant #{n}" }
    role { "Team Member" }
  end
end
