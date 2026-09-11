require "resolv"

# One IP -> MAC -> vendor resolution, as reported by the desktop client.
class Lookup < ApplicationRecord
  STATUSES = %w[found unknown error].freeze

  # Invalid input is kept as-is (just trimmed) so the format validation can reject it.
  normalizes :mac_address, with: ->(mac) { MacAddress.normalize(mac) || mac.strip }
  normalizes :ip_address, with: ->(ip) { ip.strip }

  # ARP only maps IPv4 addresses, so that is all a lookup can carry.
  validates :ip_address, presence: true, format: { with: Resolv::IPv4::Regex, message: "is not a valid IPv4 address" }
  validates :mac_address, presence: true, format: { with: MacAddress::CANONICAL, message: "is not a valid MAC address" }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
