class CreateTrainmasterUsers < ActiveRecord::Migration[5.0]
  def change
    create_table :trainmaster_users, id: false, force: :cascade do |t|
      t.string :uuid, primary_key: true, null: false
      t.string :username
      t.string :password_digest
      t.integer :role
      t.string :reset_token
      t.string :verification_token
      t.boolean :verified, default: false
      t.string :type
      t.string :api_key, index: true
      t.string :oauth_provider
      t.string :oauth_uid
      t.string :oauth_name
      t.string :oauth_token
      t.string :oauth_expires_at
      t.datetime :deleted_at, index: true
      t.timestamps null: false
    end
    add_index "trainmaster_users", ["oauth_provider", "oauth_uid"], name: "index_trainmaster_users_on_oauth_provider_and_oauth_uid"
  end
end
