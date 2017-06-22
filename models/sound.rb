class Sound
  include Mongoid::Document
  include Mongoid::Timestamps

  field :position, type: Integer
  field :visible,  type: Boolean, default: false
  field :included, type: Boolean, default: false
  field :duration, type: Float
  field :url,      type: String
  field :color,    type: String

  embedded_in :chain

  def initialize(attrs = nil)
    super attrs && attrs.merge(color: random_color) || { color: random_color }
  end

  def to_h
    {
      id: id.to_s,
      url: url,
      duration: duration,
      position: position,
      color: color
    }
  end

  private

  def random_color
    ''.tap { |word| 3.times { word.concat rand(256).to_s(16).rjust(2, '0').upcase } }
  end
end
