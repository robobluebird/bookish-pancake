require_relative './interesting'

class BuildAudio
  extend Interesting

  def self.perform(chain_id)
    chain = Chain.find chain_id

    data, time = combine_sounds chain.included_sounds

    path = upload_to_s3 'chains', data, time, chain.url

    chain.update! url: path if path
  end
end
