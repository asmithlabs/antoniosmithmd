class GraphController < ApplicationController
  def show
    @graph = KnowledgeGraph.current
    respond_to do |f|
      f.html
      f.json { render json: @graph.as_json }
    end
  end
end
