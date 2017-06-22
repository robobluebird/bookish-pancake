class AccessToken
  include Mongoid::Document
  include Mongoid::Timestamps

  field :token
end
