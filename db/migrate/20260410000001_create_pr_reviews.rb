# frozen_string_literal: true

class CreatePrReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :pr_reviews do |t|
      t.string  :github_repo,  null: false
      t.integer :pr_number,    null: false
      t.string  :pr_title
      t.text    :pr_body
      t.string  :head_sha,     null: false
      t.text    :diff_json
      t.text    :review_body
      t.string  :review_url
      t.datetime :submitted_at

      t.timestamps
    end

    add_index :pr_reviews, %i[github_repo pr_number head_sha], unique: true
  end
end
