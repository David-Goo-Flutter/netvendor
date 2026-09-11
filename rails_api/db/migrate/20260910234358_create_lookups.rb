class CreateLookups < ActiveRecord::Migration[8.1]
  def change
    create_table :lookups do |t|
      t.string :ip_address, null: false
      t.string :mac_address, null: false
      t.string :vendor
      t.string :status, null: false
      t.jsonb :raw_response

      t.timestamps
    end
    # Cache lookups in VendorLookupService query by MAC.
    add_index :lookups, :mac_address
    # GET /lookups lists newest first.
    add_index :lookups, :created_at
  end
end
