class Sound
  include Mongoid::Document
  include Mongoid::Timestamps

  field :position
  field :visible,  default: false
  field :included, default: false
  field :duration
  field :url
  field :color
  field :token

  embedded_in :circle

  def initialize(attrs = nil)
    super attrs && attrs.merge(color: random_color) || { color: random_color }
  end

  def to_h
    {
      id: id.to_s,
      url: url,
      duration: duration,
      position: position,
      color: color,
      token: token
    }
  end

  private

  def random_color
    ''.tap { |word| 3.times { word.concat rand(256).to_s(16).rjust(2, '0').upcase } }
  end
end
