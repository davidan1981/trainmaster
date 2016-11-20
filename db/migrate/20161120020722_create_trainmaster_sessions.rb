class CreateTrainmasterSessions < ActiveRecord::Migration[5.0]
  def change
    create_table :trainmaster_sessions, id: false, force: :cascade do |t|
      t.string :uuid, primary_key: true, null: false
      t.string :user_uuid, null: false
      t.string :token, null: false
      t.string :secret, null: false
      t.timestamps null: false
    end
  end
end
