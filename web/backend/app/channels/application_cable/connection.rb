module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :uuid

    def connect
      # We don't have user accounts so use a random UUID
      self.uuid = SecureRandom.uuid
    end
  end
end
