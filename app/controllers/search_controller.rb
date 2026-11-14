class SearchController < ApplicationController
  def index
    @q = params[:q].to_s.strip.first(100)
    @results = @q.present? ? Post.search(@q) : []
  end
end
