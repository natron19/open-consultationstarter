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
