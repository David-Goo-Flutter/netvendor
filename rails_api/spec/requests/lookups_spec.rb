require "rails_helper"

RSpec.describe "Lookups", type: :request do
  let(:json) { response.parsed_body }

  def vendor_result(status:, vendor: nil, mac: "18:a5:ff:45:44:28", cached: false)
    VendorLookupService::Result.new(mac_address: mac, vendor: vendor, status: status,
                                    raw_response: { "provider" => "test" }, cached: cached)
  end

  def expect_error(code, http_status: :unprocessable_content)
    expect(response).to have_http_status(http_status)
    expect(json["error"]).to include("code" => code, "message" => be_present)
  end

  describe "POST /lookups" do
    let(:params) { { ip_address: "192.168.12.1", mac_address: "18-A5-FF-45-44-28" } }

    context "when the vendor is found" do
      before do
        allow(VendorLookupService).to receive(:call)
          .and_return(vendor_result(status: "found", vendor: "Arcadyan Corporation"))
      end

      it "creates the lookup and returns it" do
        expect { post "/lookups", params: params, as: :json }.to change(Lookup, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json).to include(
          "id" => Lookup.last.id,
          "ip_address" => "192.168.12.1",
          "mac_address" => "18:a5:ff:45:44:28",
          "vendor" => "Arcadyan Corporation",
          "status" => "found",
          "cached" => false
        )
        expect(json).not_to have_key("raw_response")
      end

      it "passes the normalized MAC to the vendor service" do
        post "/lookups", params: params, as: :json
        expect(VendorLookupService).to have_received(:call).with("18:a5:ff:45:44:28")
      end
    end

    context "when every vendor provider fails" do
      before { allow(VendorLookupService).to receive(:call).and_return(vendor_result(status: "error")) }

      it "still records the attempt with status error" do
        expect { post "/lookups", params: params, as: :json }.to change(Lookup, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json).to include("status" => "error", "vendor" => nil)
      end
    end

    context "with invalid input" do
      before { allow(VendorLookupService).to receive(:call) }

      it "rejects a missing MAC" do
        post "/lookups", params: { ip_address: "192.168.12.1" }, as: :json
        expect_error("missing_parameter")
        expect(json.dig("error", "message")).to include("mac_address")
      end

      it "rejects a request with no body" do
        post "/lookups", as: :json
        expect_error("missing_parameter")
      end

      it "rejects a malformed IP" do
        post "/lookups", params: params.merge(ip_address: "999.1.1.1"), as: :json
        expect_error("invalid_ip_address")
      end

      it "rejects a malformed MAC" do
        post "/lookups", params: params.merge(mac_address: "(incomplete)"), as: :json
        expect_error("invalid_mac_address")
      end

      it "never calls the vendor service or persists" do
        expect { post "/lookups", params: params.merge(mac_address: "nope"), as: :json }.not_to change(Lookup, :count)
        expect(VendorLookupService).not_to have_received(:call)
      end
    end
  end

  describe "GET /lookups?mac=" do
    it "returns the vendor without persisting" do
      allow(VendorLookupService).to receive(:call)
        .and_return(vendor_result(status: "found", vendor: "Arcadyan Corporation"))

      expect { get "/lookups", params: { mac: "18:A5:FF:45:44:28" } }.not_to change(Lookup, :count)

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "mac_address" => "18:a5:ff:45:44:28", "vendor" => "Arcadyan Corporation", "status" => "found", "cached" => false
      )
    end

    it "returns 200 with status unknown when the vendor isn't known" do
      allow(VendorLookupService).to receive(:call).and_return(vendor_result(status: "unknown"))

      get "/lookups", params: { mac: "18:a5:ff:45:44:28" }

      expect(response).to have_http_status(:ok)
      expect(json).to include("status" => "unknown", "vendor" => nil)
    end

    it "returns 502 when every vendor provider fails" do
      allow(VendorLookupService).to receive(:call).and_return(vendor_result(status: "error"))

      get "/lookups", params: { mac: "18:a5:ff:45:44:28" }

      expect_error("vendor_lookup_unavailable", http_status: :bad_gateway)
    end

    it "rejects a blank mac" do
      get "/lookups", params: { mac: "" }
      expect_error("missing_parameter")
    end

    it "rejects a malformed mac" do
      get "/lookups", params: { mac: "zz:zz" }
      expect_error("invalid_mac_address")
    end
  end

  describe "GET /lookups" do
    it "lists lookups newest first without raw responses" do
      older = create(:lookup, ip_address: "192.168.12.1", created_at: 2.minutes.ago)
      newer = create(:lookup, :unknown, ip_address: "192.168.12.2", created_at: 1.minute.ago)

      get "/lookups"

      expect(response).to have_http_status(:ok)
      expect(json["lookups"].map { |l| l["id"] }).to eq([ newer.id, older.id ])
      expect(json["lookups"].first.keys).to contain_exactly("id", "ip_address", "mac_address", "vendor", "status", "created_at")
      expect(json["meta"]).to eq("page" => 1, "per_page" => 20, "total_count" => 2, "total_pages" => 1)
    end

    it "paginates" do
      lookups = Array.new(3) { |i| create(:lookup, created_at: i.minutes.ago) }

      get "/lookups", params: { page: 2, per_page: 2 }

      expect(json["lookups"].map { |l| l["id"] }).to eq([ lookups.last.id ])
      expect(json["meta"]).to include("page" => 2, "per_page" => 2, "total_count" => 3, "total_pages" => 2)
    end

    it "clamps per_page and page to sane bounds" do
      get "/lookups", params: { page: -3, per_page: 10_000 }

      expect(json["meta"]).to include("page" => 1, "per_page" => LookupsController::MAX_PER_PAGE)
    end
  end
end
