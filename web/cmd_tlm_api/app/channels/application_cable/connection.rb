module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :uuid #, :token

    def connect
      # We don't have user accounts so use a random UUID
      self.uuid = SecureRandom.uuid
      # TODO: token? I saw some rails code using this
      # self.token = request.params[:token] ||
      #   request.cookies["token"] ||
      #   request.headers["X-API-TOKEN"]
    end
  end
end
