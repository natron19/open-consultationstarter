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
