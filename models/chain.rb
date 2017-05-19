class Chain
  include Mongoid::Document
  include Mongoid::Timestamps

  field :description
  field :duration
  field :url

  embeds_many :sounds
  embeds_one :creator, as: :creatable

  def to_h
    {
      id: id.to_s,
      description: description,
      url: url,
      duration: duration,
      creator: creator.to_h,
      sounds: included_sounds.map(&:to_h)
    }
  end

  def included_sounds
    sounds.where(visible: true, included: true).order_by(position: :asc)
  end

  def next_position
    if sounds.any?
      sounds.order_by(position: :desc).first.position + 1
    else
      1
    end
  end

  def add_sound!(attrs = {})
    pos = (append_id = attrs.delete(:before)).nil? ? next_position : shift_positions(append_id)

    return if pos.nil?

    sounds.create! attrs.merge position: pos, included: true, visible: true
  end

  def build!

  end

  private

  def shift_positions id
    sound = sounds.find id
    shift_upward_starting_at sound
  rescue
    nil
  end


  def shift_upward_starting_at sound
    pos = sound.position

    sounds.where(:position.gte => pos).each do |sound|
      sound.inc(position: 1)
    end

    pos
  end
end
