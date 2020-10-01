require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "successfully connects" do
    connect "/cable"
    expect(connection.uuid).to be_a(String) # Any random string will do
  end
end
