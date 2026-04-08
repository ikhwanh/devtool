# frozen_string_literal: true

class CreateGithubIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :github_issues do |t|
      t.references :rollbar_item, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      t.text :labels # JSON array stored as text
      t.string :github_issue_url
      t.integer :github_issue_number
      t.datetime :submitted_at

      t.timestamps
    end

    add_index :github_issues, :github_issue_url
  end
end
