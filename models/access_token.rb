class AccessToken
  include Mongoid::Document
  include Mongoid::Timestamps

  field :token
  field :banned, default: false
  field :starred, type: Array, default: Array.new

  def initialize(attrs = nil)
    attrs = {} if attrs.nil?

    attrs.merge(token: SecureRandom.uuid) if attrs[:token].nil?

    super attrs
  end
end
