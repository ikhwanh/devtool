# frozen_string_literal: true

class AddProjectToRollbarItems < ActiveRecord::Migration[8.1]
  def change
    add_column :rollbar_items, :project, :string
  end
end
