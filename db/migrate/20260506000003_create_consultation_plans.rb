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
