# frozen_string_literal: true

class AddCommentsJsonToPrReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :pr_reviews, :comments_json, :text
  end
end
