require 'securerandom'

class TemporaryToken
  include Mongoid::Document
  include Mongoid::Timestamps

  field :token

  def initialize(attrs = nil)
    super attrs && attrs.merge(code: SecureRandom.uuid) || { code: SecureRandom.uuid }
  end

  def self.validate!(provided_code)
    c = find_by code: provided_code
    c.destroy && Time.now.utc - c.created_at.utc < 10
  rescue
    false
  end
end