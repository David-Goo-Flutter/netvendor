FactoryBot.define do
  factory :lookup do
    ip_address { "192.168.1.1" }
    mac_address { "18:a5:ff:45:44:28" }
    vendor { "Arcadyan Corporation" }
    status { "found" }
    raw_response { { "provider" => "maclookup.app" } }

    trait :unknown do
      vendor { nil }
      status { "unknown" }
    end
  end
end
