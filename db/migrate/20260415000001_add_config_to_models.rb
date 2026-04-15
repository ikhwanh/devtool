# frozen_string_literal: true

class AddConfigToModels < ActiveRecord::Migration[8.1]
  def change
    add_column :rollbar_items, :config, :string
    add_column :github_issues, :config, :string
    add_column :pr_reviews,    :config, :string

    reversible do |dir|
      dir.up do
        default_project = Config.default_project
        if default_project
          RollbarItem.where(config: nil).update_all(config: default_project)
          GithubIssue.where(config: nil).update_all(config: default_project)
          PrReview.where(config: nil).update_all(config: default_project)
        end
      end
    end

    change_column_null :rollbar_items, :config, false
    change_column_null :github_issues, :config, false
    change_column_null :pr_reviews,    :config, false

    add_index :rollbar_items, :config
    add_index :github_issues, :config
    add_index :pr_reviews,    :config
  end
end
