# Resolves a MAC address to its hardware vendor.
#
# Resolution order:
#   1. Locally administered (randomized) MACs answer "unknown" right away -- no vendor exists.
#   2. A previous found/unknown Lookup row for the same MAC is reused (no network call).
#   3. maclookup.app, falling back to api.macvendors.com when the first provider fails.
#
# The service never writes to the database; callers decide whether to persist the result.
class VendorLookupService
  Result = Data.define(:mac_address, :vendor, :status, :raw_response, :cached)

  class InvalidMacAddress < ArgumentError; end

  # A provider couldn't give a definitive answer (timeout, 5xx, rate limit, garbage body).
  # Distinct from "unknown", which is a definitive "this OUI isn't registered".
  class ProviderError < StandardError; end

  PROVIDERS = %i[maclookup_app macvendors_com].freeze
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 5

  def self.call(mac_address)
    new.call(mac_address)
  end

  def call(mac_address)
    mac = MacAddress.normalize(mac_address)
    raise InvalidMacAddress, "#{mac_address.inspect} is not a valid MAC address" unless mac

    return randomized_result(mac) if MacAddress.locally_administered?(mac)

    cached_result(mac) || remote_result(mac)
  end

  private

  def randomized_result(mac)
    Result.new(mac_address: mac, vendor: nil, status: "unknown",
               raw_response: { "reason" => "locally_administered" }, cached: false)
  end

  def cached_result(mac)
    hit = Lookup.where(mac_address: mac, status: %w[found unknown]).order(created_at: :desc).first
    return unless hit

    Result.new(mac_address: mac, vendor: hit.vendor, status: hit.status,
               raw_response: hit.raw_response, cached: true)
  end

  def remote_result(mac)
    errors = []

    PROVIDERS.each do |provider|
      return send(provider, mac)
    rescue ProviderError, Faraday::Error => e
      errors << { "provider" => provider.to_s, "error" => e.message }
    end

    Result.new(mac_address: mac, vendor: nil, status: "error",
               raw_response: { "errors" => errors }, cached: false)
  end

  # https://maclookup.app/api-v2/documentation
  # 200 {"success":true,"found":true,"company":"..."} or {"success":true,"found":false,...}
  def maclookup_app(mac)
    params = ENV["MACLOOKUP_API_KEY"].present? ? { apiKey: ENV["MACLOOKUP_API_KEY"] } : {}
    response = connection("https://api.maclookup.app").get("/v2/macs/#{mac}", params)
    raise ProviderError, "maclookup.app responded #{response.status}" unless response.status == 200

    body = parse_json(response.body)
    raise ProviderError, "maclookup.app returned an unexpected body" unless body.is_a?(Hash) && body["success"]

    vendor = body["found"] ? body["company"].presence : nil
    build_result(mac, vendor, { "provider" => "maclookup.app", "body" => body })
  end

  # https://macvendors.com/api -- plain-text vendor name on 200, 404 when the OUI is unregistered.
  def macvendors_com(mac)
    response = connection("https://api.macvendors.com").get("/#{mac}")

    case response.status
    when 200
      vendor = response.body.to_s.strip
      build_result(mac, vendor.presence, { "provider" => "macvendors.com", "body" => vendor })
    when 404
      build_result(mac, nil, { "provider" => "macvendors.com", "body" => parse_json(response.body) })
    else
      raise ProviderError, "macvendors.com responded #{response.status}"
    end
  end

  def build_result(mac, vendor, raw_response)
    Result.new(mac_address: mac, vendor: vendor, status: vendor ? "found" : "unknown",
               raw_response: raw_response, cached: false)
  end

  def connection(base_url)
    Faraday.new(url: base_url, request: { open_timeout: OPEN_TIMEOUT, timeout: READ_TIMEOUT })
  end

  def parse_json(raw)
    JSON.parse(raw.to_s)
  rescue JSON::ParserError
    raise ProviderError, "invalid JSON from provider"
  end
end
