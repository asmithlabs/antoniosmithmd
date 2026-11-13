class AddTitleHtmlToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :title_html, :text
  end
end
