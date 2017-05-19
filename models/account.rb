class Account
  include Mongoid::Document
  include Mongoid::Timestamps

  field :api_key
  field :handle

  def to_h
    {
      id: id.to_s,
      handle: handle
    }
  end
end
