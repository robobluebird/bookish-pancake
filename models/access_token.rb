class AccessToken
  include Mongoid::Document
  include Mongoid::Timestamps

  field :token
  field :banned, default: false

  def initialize(attrs = nil)
    super attrs && attrs.merge(token: SecureRandom.uuid) || { token: SecureRandom.uuid }
  end
end
