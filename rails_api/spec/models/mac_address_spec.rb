require "rails_helper"

RSpec.describe MacAddress do
  describe ".normalize" do
    {
      "AA:BB:CC:DD:EE:FF" => "aa:bb:cc:dd:ee:ff",     # already canonical, just cased
      "aa:bb:cc:dd:ee:ff" => "aa:bb:cc:dd:ee:ff",
      "aa-bb-cc-dd-ee-ff" => "aa:bb:cc:dd:ee:ff",     # dash-separated
      "AA-BB-CC-DD-EE-FF" => "aa:bb:cc:dd:ee:ff",
      "0:1a:2b:3:4:5" => "00:1a:2b:03:04:05",         # unpadded octets (macOS `arp -a`)
      "aabb.ccdd.eeff" => "aa:bb:cc:dd:ee:ff",        # Cisco dotted
      "AABB.CCDD.EEFF" => "aa:bb:cc:dd:ee:ff",
      "aabbccddeeff" => "aa:bb:cc:dd:ee:ff",          # bare hex
      "  aa:bb:cc:dd:ee:ff  \n" => "aa:bb:cc:dd:ee:ff" # surrounding whitespace
    }.each do |input, expected|
      it "normalizes #{input.inspect} to #{expected.inspect}" do
        expect(described_class.normalize(input)).to eq(expected)
      end
    end

    [
      nil, "", "aa:bb:cc:dd:ee", "aa:bb:cc:dd:ee:ff:gg", "gg:bb:cc:dd:ee:ff",
      "aa:bb-cc:dd:ee:ff", "aabbccddeeff0", "(incomplete)", "not-a-mac"
    ].each do |input|
      it "returns nil for #{input.inspect}" do
        expect(described_class.normalize(input)).to be_nil
      end
    end
  end

  describe ".valid?" do
    it "is true for a MAC in any accepted format" do
      expect(described_class.valid?("18-A5-FF-45-44-28")).to be true
    end

    it "is false for garbage" do
      expect(described_class.valid?("nope")).to be false
    end

    it "is false for nil" do
      expect(described_class.valid?(nil)).to be false
    end
  end

  describe ".locally_administered?" do
    it "is true when bit 1 of the first octet is set (software-assigned, e.g. iOS/Android private Wi-Fi MACs)" do
      expect(described_class.locally_administered?("92:90:ae:e9:5f:6b")).to be true
    end

    it "is true for the canonical locally-administered example 02:00:00:00:00:00" do
      expect(described_class.locally_administered?("02:00:00:00:00:00")).to be true
    end

    it "is false for a real, manufacturer-assigned MAC" do
      expect(described_class.locally_administered?("18:a5:ff:45:44:28")).to be false
    end

    it "is false for a universally administered address with the multicast bit set but not the locally-administered bit" do
      # 0x01 = 00000001: bit 0 (multicast) is set, bit 1 (locally administered) is not.
      expect(described_class.locally_administered?("01:00:5e:00:00:fb")).to be false
    end

    it "accepts an already-normalized, unpadded, or differently-separated MAC identically" do
      expect(described_class.locally_administered?("2:0:0:0:0:0")).to be true
      expect(described_class.locally_administered?("02-00-00-00-00-00")).to be true
    end

    it "is false, not an error, for invalid input" do
      expect(described_class.locally_administered?("not-a-mac")).to be false
      expect(described_class.locally_administered?(nil)).to be false
    end
  end
end
