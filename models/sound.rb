class Sound
  include Mongoid::Document
  include Mongoid::Timestamps

  field :position, type: Integer
  field :visible,  type: Boolean, default: true
  field :included, type: Boolean, default: false
  field :duration, type: Float
  field :url,      type: String
  field :color,    type: String

  embedded_in :chain
  embeds_one :creator, as: :creatable

  def to_h
    {
      id: id.to_s,
      url: url,
      duration: duration,
      position: position,
      creator: creator.to_h
    }
  end
end
