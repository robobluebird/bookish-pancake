require_relative './interesting'
require_relative './chain'
require_relative './sound'

class BuildAudio
  extend Interesting

  def self.perform(chain_id, new_sounds = nil)
    chain = Chain.find chain_id

    data, time = combine_sounds chain.included_sounds

    return if data.nil? || data.size == 0 || time.zero?

    path = upload_to_s3 'chains', data, time, chain.url

    chain.visiblize(new_sounds).inc(queued_build_count: -1).update(url: path, duration: time) if path
  end
end
