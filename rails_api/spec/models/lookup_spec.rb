require "rails_helper"

RSpec.describe Lookup, type: :model do
  subject(:lookup) { build(:lookup) }

  it { is_expected.to be_valid }
  it { is_expected.to validate_presence_of(:ip_address) }
  it { is_expected.to validate_presence_of(:mac_address) }
  it { is_expected.to validate_inclusion_of(:status).in_array(Lookup::STATUSES) }

  describe "ip_address" do
    %w[192.168.1.1 10.0.0.254 0.0.0.0].each do |ip|
      it "accepts #{ip}" do
        expect(build(:lookup, ip_address: ip)).to be_valid
      end
    end

    %w[256.1.1.1 192.168.1 192.168.1.1/24 fe80::1 not-an-ip].each do |ip|
      it "rejects #{ip}" do
        expect(build(:lookup, ip_address: ip)).not_to be_valid
      end
    end

    it "strips surrounding whitespace" do
      expect(build(:lookup, ip_address: " 10.0.0.1 \n").ip_address).to eq("10.0.0.1")
    end
  end

  describe "mac_address" do
    {
      "AA:BB:CC:DD:EE:FF" => "aa:bb:cc:dd:ee:ff",
      "aa-bb-cc-dd-ee-ff" => "aa:bb:cc:dd:ee:ff",
      "aabb.ccdd.eeff" => "aa:bb:cc:dd:ee:ff",
      "AABBCCDDEEFF" => "aa:bb:cc:dd:ee:ff",
      "0:1a:2b:3:4:5" => "00:1a:2b:03:04:05" # macOS `arp -a` drops leading zeros
    }.each do |input, canonical|
      it "normalizes #{input} to #{canonical}" do
        lookup = build(:lookup, mac_address: input)
        expect(lookup.mac_address).to eq(canonical)
        expect(lookup).to be_valid
      end
    end

    %w[aa:bb:cc:dd:ee gg:bb:cc:dd:ee:ff aa:bb-cc:dd:ee:ff aabbccddeeff00 (incomplete)].each do |input|
      it "rejects #{input}" do
        expect(build(:lookup, mac_address: input)).not_to be_valid
      end
    end
  end

  describe ".recent" do
    it "orders newest first" do
      older = create(:lookup, created_at: 2.minutes.ago)
      newer = create(:lookup, created_at: 1.minute.ago)

      expect(described_class.recent).to eq([ newer, older ])
    end
  end
end
