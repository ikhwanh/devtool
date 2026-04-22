class AddRollbarCounterToRollbarItems < ActiveRecord::Migration[8.0]
  def change
    add_column :rollbar_items, :rollbar_counter, :integer
    add_index :rollbar_items, :rollbar_counter
  end
end
