# frozen_string_literal: true

class AddLinkedIssuesJsonToPrReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :pr_reviews, :linked_issues_json, :text
  end
end
