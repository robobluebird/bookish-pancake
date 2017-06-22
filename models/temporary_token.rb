require 'securerandom'

class TemporaryToken
  include Mongoid::Document
  include Mongoid::Timestamps

  field :token

  def initialize(attrs = nil)
    super attrs && attrs.merge(token: SecureRandom.uuid) || { token: SecureRandom.uuid }
  end

  def self.validate!(provided_token)
    c = find_by token: provided_token
    c.destroy && Time.now.utc - c.created_at.utc < 10
  rescue
    false
  end
end