require 'securerandom'

class Circle
  include Mongoid::Document
  include Mongoid::Timestamps

  field :description
  field :duration
  field :url
  field :code
  field :queued_build_count, default: 0
  field :token
  field :visible, default: true

  embeds_many :sounds

  def self.visible
    where visible: true
  end

  def initialize(attrs = nil)
    super attrs && attrs.merge(code: random_code) || { code: random_code }
  end

  def random_code
    code = SecureRandom.hex(2).upcase

    loop do
      if self.class.where(code: code).exists?
        code = SecureRandom.hex(2).upcase
      else
        break
      end
    end

    code
  end

  def to_h(starred_circle_ids = [])
    {
      id: id.to_s,
      url: url,
      duration: duration,
      code: code,
      queued_build_count: queued_build_count,
      token: token,
      sounds: visible_sounds.map(&:to_h),
      starred: starred_circle_ids.include?(id.to_s)
    }
  end

  def included_sounds
    sounds.where(included: true).order_by position: :asc
  end

  def visible_sounds(other_sounds = [])
    sounds.or({ visible: true }, { :_id.in => other_sounds })
      .order_by position: :asc
  end

  def visiblize(sound_ids)
    return self if sound_ids.nil? || sound_ids.empty?

    sounds.find(sound_ids).each { |sound| sound.update visible: true }

    self
  end

  def unvisiblize(sound_ids)
    return self if sound_ids.nil? || sound_ids.empty?

    sounds.find(sound_ids).each { |sound| sound.update visible: false }

    self
  end

  def next_position
    sounds.any? ? sounds.order_by(position: :desc).first.position + 1 : 1
  end

  def add_sound(attrs = {})
    pos = (append_id = attrs.delete(:before)).nil? ? next_position : shift_positions(append_id)

    return if pos.nil?

    sounds.create attrs.merge position: pos, included: true
  end

  private

  def shift_positions(id)
    sound = sounds.find id
    shift_upward_starting_at sound
  rescue
    nil
  end


  def shift_upward_starting_at(sound)
    pos = sound.position

    sounds.where(:position.gte => pos).each do |sound|
      sound.inc(position: 1)
    end

    pos
  end
end
