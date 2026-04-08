# frozen_string_literal: true

class CreateRollbarItems < ActiveRecord::Migration[8.1]
  def change
    create_table :rollbar_items do |t|
      t.integer :rollbar_id, null: false
      t.string :title, null: false
      t.string :environment
      t.string :severity
      t.integer :total_occurrences, default: 0
      t.datetime :last_occurrence_at
      t.text :occurrence_data # JSON blob for full occurrence detail
      t.boolean :selected, default: false, null: false

      t.timestamps
    end

    add_index :rollbar_items, :rollbar_id, unique: true
    add_index :rollbar_items, :severity
    add_index :rollbar_items, :selected
  end
end
