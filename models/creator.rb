class Creator
  include Mongoid::Document
  include Mongoid::Timestamps

  field :handle
  field :account_id, type: String

  embedded_in :creatable, polymorphic: true

  def to_h
    { handle: handle }
  end

  def self.new_with_account account
    new(handle: account.handle, account_id: account.id)
  end
end