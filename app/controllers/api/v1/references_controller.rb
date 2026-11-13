module Api
  module V1
    class ReferencesController < BaseController
      # GET /api/v1/references?q=alert+fatigue   — search the cached Zotero library
      def index
        render json: Reference.search(params[:q], limit: (params[:limit] || 10).to_i.clamp(1, 50)).map { |r|
          { key: r.citekey, cite: "[@#{r.citekey}]", authors: r.authors, year: r.year, title: r.title, type: r.item_type, doi: r.doi, url: r.link }
        }
      end
    end
  end
end
