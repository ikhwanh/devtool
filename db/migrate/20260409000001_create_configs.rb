# frozen_string_literal: true

class CreateConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :configs do |t|
      t.string  :project,    null: false
      t.string  :key,        null: false
      t.string  :value
      t.boolean :is_default, null: false, default: false

      t.timestamps
    end

    add_index :configs, %i[project key], unique: true
    add_index :configs, :is_default
  end
end
