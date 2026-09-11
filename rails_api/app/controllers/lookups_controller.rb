class LookupsController < ApplicationController
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  # GET /lookups            recent history, newest first (paginated)
  # GET /lookups?mac=...    vendor lookup only -- nothing is persisted, so GET stays side-effect free
  def index
    params.key?(:mac) ? vendor_only : history
  end

  # POST /lookups  { "ip_address": "192.168.1.1", "mac_address": "aa:bb:cc:dd:ee:ff" }
  # Resolves the vendor and records the lookup. A failed vendor resolution is still
  # recorded (status "error") so the history shows what happened.
  def create
    missing = %i[ip_address mac_address].select { |key| params[key].blank? }
    if missing.any?
      return render_error(:missing_parameter, "Missing required parameter(s): #{missing.join(', ')}")
    end

    lookup = Lookup.new(ip_address: params[:ip_address].to_s, mac_address: params[:mac_address].to_s, status: "unknown")
    # Validate before spending an external API call on bad input.
    return render_invalid(lookup) if lookup.invalid?

    result = VendorLookupService.call(lookup.mac_address)
    lookup.update!(vendor: result.vendor, status: result.status, raw_response: result.raw_response)

    render json: lookup_json(lookup).merge("cached" => result.cached), status: :created
  end

  private

  def vendor_only
    return render_error(:missing_parameter, "mac must not be blank") if params[:mac].blank?

    result = VendorLookupService.call(params[:mac].to_s)
    if result.status == "error"
      render_error(:vendor_lookup_unavailable, "All vendor lookup providers failed; try again later",
                   status: :bad_gateway)
    else
      render json: result.to_h.slice(:mac_address, :vendor, :status, :cached)
    end
  rescue VendorLookupService::InvalidMacAddress => e
    render_error(:invalid_mac_address, e.message)
  end

  def history
    page = [ params.fetch(:page, 1).to_i, 1 ].max
    per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
    total = Lookup.count

    render json: {
      lookups: Lookup.recent.offset((page - 1) * per_page).limit(per_page).map { |lookup| lookup_json(lookup) },
      meta: { page: page, per_page: per_page, total_count: total, total_pages: (total.to_f / per_page).ceil }
    }
  end

  def render_invalid(lookup)
    attribute = lookup.errors.attribute_names.first
    code = { ip_address: :invalid_ip_address, mac_address: :invalid_mac_address }.fetch(attribute, :validation_failed)
    render_error(code, lookup.errors.full_messages.to_sentence)
  end

  # raw_response is kept in the database for debugging but not exposed to clients.
  def lookup_json(lookup)
    lookup.as_json(only: %i[id ip_address mac_address vendor status created_at])
  end
end
