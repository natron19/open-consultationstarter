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
