require 'cocaine'
require 'aws-sdk'
require 'date'

module Interesting
  def current_token
    @current_token ||= AccessToken.find_by(token: request.authorization.value) rescue nil
  end

  def aws_client
    @aws_client ||= Aws::S3::Client.new
  end

  def file_path(opts = {})
    File.join opts.fetch(:type), Date.today.to_s, "#{Time.now.to_i}.#{opts.fetch(:extension)}"
  end

  def upload
    (params[:upload] || {})
  end

  def fetch_sound(sound)
    aws_client.get_object bucket: 'tel-serv', key: sound.url
  end

  def fetch_sounds(sounds)
    sounds.map do |sound|
      response = fetch_sound sound
      response.body.rewind

      tempfile = Tempfile.new ['', '.mp3']
      tempfile.binmode
      tempfile.write response.body.read
      tempfile
    end
  end

  def sound_duration(sound)
    cmd = Cocaine::CommandLine.new('sox', ":in -n stat 2>&1 | grep 'Length (seconds)'")
    match = /(\d+\.\d+)/.match cmd.run in: sound.path
    match.captures.first.to_f.round 4
  rescue
    0
  end

  def convert_sound_format_to_mp3(sound)
    tempfile = Tempfile.new ['', '.mp3']

    Cocaine::CommandLine.new('ffmpeg', '-i :in -acodec libmp3lame -y -b:a 96k -ar 44100 -ac 1 :out')
      .run(in: sound.path, out: tempfile.path)

    tempfile
  end

  def process_sound(sound, mime_type)
    return unless sound and mime_type

    tempfile = Tempfile.new ['', '.mp3']

    ready = mime_type.end_with?('mp3') ? sound : convert_sound_format_to_mp3(sound)

    Cocaine::CommandLine.new('sox', ':in -c 1 -C 96 :out compand 0.3,1 6:-70,-60,-20 -5 -90 norm riaa fade 0.5 reverse fade 0.5 reverse')
      .run(in: ready.path, out: tempfile.path)

    [tempfile.read, sound_duration(tempfile)]
  end

  def combine_sounds(sounds = [])
    sound_files = fetch_sounds sounds

    return if sound_files.empty? || sound_files.nil?

    tempfile = Tempfile.new ['', '.mp3']

    Cocaine::CommandLine.new('sox', "#{sound_files.map(&:path).join(' ')} :out splice").run(out: tempfile.path)

    [tempfile.read, sound_duration(tempfile)]
  end

  def upload_to_s3(type, data = nil, time = nil, old_url = nil)
    return if data.nil? || data.size == 0 || time.zero? || (type == 'sounds' && time > 16)

    new_url = file_path(type: type, extension: 'mp3')

    aws_client.put_object(bucket: 'tel-serv', key: new_url, body: data)

    new_url
  end
end
