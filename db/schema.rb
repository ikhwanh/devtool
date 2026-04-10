# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_10_000001) do
  create_table "configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_default", default: false, null: false
    t.string "key", null: false
    t.string "project", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["is_default"], name: "index_configs_on_is_default"
    t.index ["project", "key"], name: "index_configs_on_project_and_key", unique: true
  end

  create_table "github_issues", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "github_issue_number"
    t.string "github_issue_url"
    t.text "labels"
    t.integer "rollbar_item_id", null: false
    t.datetime "submitted_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["github_issue_url"], name: "index_github_issues_on_github_issue_url"
    t.index ["rollbar_item_id"], name: "index_github_issues_on_rollbar_item_id"
  end

  create_table "pr_reviews", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "diff_json"
    t.string "github_repo", null: false
    t.string "head_sha", null: false
    t.text "pr_body"
    t.integer "pr_number", null: false
    t.string "pr_title"
    t.text "review_body"
    t.string "review_url"
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.index ["github_repo", "pr_number", "head_sha"], name: "index_pr_reviews_on_github_repo_and_pr_number_and_head_sha", unique: true
  end

  create_table "rollbar_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "environment"
    t.datetime "last_occurrence_at"
    t.text "occurrence_data"
    t.string "project"
    t.integer "rollbar_id", null: false
    t.boolean "selected", default: false, null: false
    t.string "severity"
    t.string "title", null: false
    t.integer "total_occurrences", default: 0
    t.datetime "updated_at", null: false
    t.index ["rollbar_id"], name: "index_rollbar_items_on_rollbar_id", unique: true
    t.index ["selected"], name: "index_rollbar_items_on_selected"
    t.index ["severity"], name: "index_rollbar_items_on_severity"
  end

  add_foreign_key "github_issues", "rollbar_items"
end
