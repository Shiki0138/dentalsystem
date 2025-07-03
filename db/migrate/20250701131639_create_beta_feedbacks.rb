class CreateBetaFeedbacks < ActiveRecord::Migration[7.0]
  def change
    create_table :beta_feedbacks do |t|
      t.text :message, null: false
      t.string :page
      t.string :user_agent
      t.references :clinic, foreign_key: true
      t.timestamps
    end
    
    add_index :beta_feedbacks, :created_at
  end
end
