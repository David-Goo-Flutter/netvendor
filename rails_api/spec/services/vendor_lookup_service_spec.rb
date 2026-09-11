require "rails_helper"

RSpec.describe VendorLookupService do
  subject(:result) { described_class.call(input) }

  let(:mac) { "18:a5:ff:45:44:28" }
  let(:input) { mac }
  let(:maclookup_url) { %r{\Ahttps://api\.maclookup\.app/v2/macs/#{mac}} }
  let(:macvendors_url) { "https://api.macvendors.com/#{mac}" }

  def maclookup_body(found:, company: "")
    { success: true, found: found, macPrefix: found ? "18A5FF" : "", company: company, isRand: false }.to_json
  end

  context "when maclookup.app knows the vendor" do
    before do
      stub_request(:get, maclookup_url)
        .to_return(status: 200, body: maclookup_body(found: true, company: "Arcadyan Corporation"))
    end

    it "returns a found result from the primary provider" do
      expect(result).to have_attributes(mac_address: mac, vendor: "Arcadyan Corporation", status: "found", cached: false)
      expect(result.raw_response["provider"]).to eq("maclookup.app")
      expect(a_request(:get, macvendors_url)).not_to have_been_made
    end

    it "does not persist anything" do
      expect { result }.not_to change(Lookup, :count)
    end

    context "with a non-canonical MAC" do
      let(:input) { "18-A5-FF-45-44-28" }

      it "normalizes it before calling the provider" do
        expect(result.mac_address).to eq(mac)
      end
    end
  end

  context "when maclookup.app does not know the OUI" do
    before { stub_request(:get, maclookup_url).to_return(status: 200, body: maclookup_body(found: false)) }

    it "returns unknown without asking the fallback" do
      expect(result).to have_attributes(vendor: nil, status: "unknown")
      expect(a_request(:get, macvendors_url)).not_to have_been_made
    end
  end

  context "when maclookup.app fails" do
    [
      [ "is rate limited", ->(stub) { stub.to_return(status: 429, body: "") } ],
      [ "returns a server error", ->(stub) { stub.to_return(status: 503, body: "") } ],
      [ "times out", ->(stub) { stub.to_timeout } ],
      [ "returns malformed JSON", ->(stub) { stub.to_return(status: 200, body: "<html>oops</html>") } ]
    ].each do |description, failure|
      context "because it #{description}" do
        before do
          failure.call(stub_request(:get, maclookup_url))
          stub_request(:get, macvendors_url).to_return(status: 200, body: "Arcadyan Corporation")
        end

        it "falls back to macvendors.com" do
          expect(result).to have_attributes(vendor: "Arcadyan Corporation", status: "found")
          expect(result.raw_response["provider"]).to eq("macvendors.com")
        end
      end
    end

    it "treats a macvendors.com 404 as unknown" do
      stub_request(:get, maclookup_url).to_return(status: 500)
      stub_request(:get, macvendors_url).to_return(status: 404, body: { errors: { detail: "Not Found" } }.to_json)

      expect(result).to have_attributes(vendor: nil, status: "unknown")
    end
  end

  context "when every provider fails" do
    before do
      stub_request(:get, maclookup_url).to_timeout
      stub_request(:get, macvendors_url).to_return(status: 429)
    end

    it "returns an error result listing each provider failure" do
      expect(result).to have_attributes(vendor: nil, status: "error", cached: false)
      expect(result.raw_response["errors"].map { |e| e["provider"] }).to eq(%w[maclookup_app macvendors_com])
    end
  end

  context "when the MAC was looked up before" do
    before { create(:lookup, mac_address: mac, vendor: "Arcadyan Corporation", status: "found") }

    it "answers from the database without calling any provider" do
      expect(result).to have_attributes(vendor: "Arcadyan Corporation", status: "found", cached: true)
      expect(a_request(:any, /.*/)).not_to have_been_made
    end
  end

  context "when the only previous lookup errored" do
    before do
      create(:lookup, mac_address: mac, vendor: nil, status: "error")
      stub_request(:get, maclookup_url)
        .to_return(status: 200, body: maclookup_body(found: true, company: "Arcadyan Corporation"))
    end

    it "does not treat the error as a cache hit" do
      expect(result).to have_attributes(status: "found", cached: false)
    end
  end

  context "with a locally administered (randomized) MAC" do
    let(:input) { "92:90:ae:e9:5f:6b" }

    it "returns unknown without any network call" do
      expect(result).to have_attributes(vendor: nil, status: "unknown")
      expect(result.raw_response).to eq("reason" => "locally_administered")
      expect(a_request(:any, /.*/)).not_to have_been_made
    end
  end

  context "with an invalid MAC" do
    let(:input) { "not-a-mac" }

    it "raises InvalidMacAddress" do
      expect { result }.to raise_error(VendorLookupService::InvalidMacAddress)
    end
  end
end
