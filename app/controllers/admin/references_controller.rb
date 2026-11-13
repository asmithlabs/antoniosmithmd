module Admin
  class ReferencesController < BaseController
    def index
      @refs = if params[:keys].present?
        keys = params[:keys].to_s.split(",").first(100)
        Reference.where(citekey: keys).or(Reference.where(zotero_key: keys.map { _1.delete_prefix("zotero:") }))
      else
        Reference.search(params[:q], limit: 100).order(:citekey)
      end
      respond_to do |f|
        f.html
        f.json { render json: @refs.first(params[:keys].present? ? 100 : 15).map { { key: _1.citekey, label: _1.short_label, title: _1.title, type: _1.item_type } } }
      end
    end

    def sync
      s = ZoteroLibrary.sync!(full: params[:full].present?)
      redirect_to admin_references_path, notice: "Zotero synced: #{s[:added]} added, #{s[:updated]} updated, #{s[:deleted]} removed."
    rescue ZoteroLibrary::Error => e
      redirect_to admin_references_path, alert: e.message
    end
  end
end
