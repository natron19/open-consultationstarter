class Participant < ApplicationRecord
  belongs_to :consultation

  validates :name, presence: true, length: { minimum: 1, maximum: 80 }
  validates :role, presence: true, length: { minimum: 1, maximum: 80 }
end
