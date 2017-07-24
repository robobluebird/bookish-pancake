require_relative './interesting'
require_relative './circle'
require_relative './sound'

class BuildAudio
  extend Interesting

  def self.perform(circle_id, visible_sounds = nil, unvisible_sounds = nil)
    circle = Circle.find circle_id

    data, time = combine_sounds circle.included_sounds

    path = upload_to_s3 'circles', data, time, circle.url

    if path
      circle.visiblize(visible_sounds)
        .unvisiblize(unvisible_sounds)
        .inc(queued_build_count: -1)
        .update(url: path, duration: time)
    end
  end
end
