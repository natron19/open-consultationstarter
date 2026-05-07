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
