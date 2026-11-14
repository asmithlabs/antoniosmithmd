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

ActiveRecord::Schema[8.1].define(version: 2026_11_14_040110) do
  create_table "api_tokens", force: :cascade do |t|
    t.string "name"
    t.string "token_digest"
    t.string "scope"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.integer "post_id", null: false
    t.integer "parent_id"
    t.string "author_name"
    t.text "body"
    t.integer "score", default: 0, null: false
    t.boolean "approved", default: true, null: false
    t.string "ip_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["post_id"], name: "index_comments_on_post_id"
  end

  create_table "passkeys", force: :cascade do |t|
    t.string "external_id"
    t.text "public_key"
    t.integer "sign_count", default: 0, null: false
    t.string "nickname"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_passkeys_on_external_id", unique: true
  end

  create_table "post_revisions", force: :cascade do |t|
    t.integer "post_id", null: false
    t.string "title"
    t.text "title_html"
    t.text "body"
    t.text "excerpt"
    t.string "editor"
    t.datetime "created_at", null: false
    t.index ["post_id"], name: "index_post_revisions_on_post_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.text "excerpt"
    t.text "body"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.string "tags"
    t.boolean "comments_enabled", default: true, null: false
    t.datetime "comments_open_at"
    t.boolean "comments_moderated", default: false, null: false
    t.boolean "featured", default: false, null: false
    t.string "source"
    t.string "source_path"
    t.text "title_html"
    t.boolean "share_mastodon", default: true, null: false
    t.string "mastodon_url"
    t.datetime "mastodon_posted_at"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
  end

  create_table "references", force: :cascade do |t|
    t.string "zotero_key"
    t.string "citekey"
    t.text "title"
    t.string "authors"
    t.string "year"
    t.string "doi"
    t.string "url"
    t.string "item_type"
    t.text "bib_html"
    t.json "data"
    t.integer "version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["citekey"], name: "index_references_on_citekey", unique: true
    t.index ["zotero_key"], name: "index_references_on_zotero_key", unique: true
  end

  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "posts"
  add_foreign_key "post_revisions", "posts"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "post_search", "fts5", ["title", "body", "tags", "tokenize='unicode61 remove_diacritics 2'", "prefix='2 3 4'"]
end
