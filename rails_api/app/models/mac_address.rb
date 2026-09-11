# Helpers for MAC address strings. Everything is stored and compared in one
# canonical form: lowercase, colon-separated, zero-padded ("aa:bb:0c:dd:ee:ff").
module MacAddress
  CANONICAL = /\A(?:[0-9a-f]{2}:){5}[0-9a-f]{2}\z/

  SEPARATED = /\A[0-9a-f]{1,2}([:-])(?:[0-9a-f]{1,2}\1){4}[0-9a-f]{1,2}\z/
  DOTTED = /\A[0-9a-f]{4}\.[0-9a-f]{4}\.[0-9a-f]{4}\z/
  BARE = /\A[0-9a-f]{12}\z/

  module_function

  # Returns the canonical form, or nil when the input isn't a MAC address.
  # Accepts colon/dash separated octets (with or without zero padding -- macOS
  # `arp` prints "0:1a:2b:3:4:5"), Cisco dotted "aabb.ccdd.eeff" and bare hex.
  def normalize(value)
    str = value.to_s.strip.downcase

    octets =
      if str.match?(SEPARATED)
        str.split(/[:-]/).map { |octet| octet.rjust(2, "0") }
      elsif str.match?(DOTTED) || str.match?(BARE)
        str.delete(".").scan(/../)
      end

    octets&.join(":")
  end

  def valid?(value)
    !normalize(value).nil?
  end

  # Locally administered addresses (bit 1 of the first octet set) are assigned by
  # software rather than burned in by a manufacturer -- e.g. the private Wi-Fi
  # addresses iOS and Android randomize per network -- so no vendor owns them.
  def locally_administered?(value)
    mac = normalize(value)
    return false unless mac

    mac[0, 2].to_i(16).anybits?(0b10)
  end
end
