require 'mongoid'
require 'qu'
require_relative './models/qu/backend/mongoid'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader' if development?

Dir['./models/*.rb'].each { |file| require file }

class Tel < Sinatra::Base
  set :show_exceptions => false
  set :raise_errors => false

  Mongoid.load! 'mongoid.yml'

  Qu.backend = Qu::Backend::Mongoid.new

  helpers Interesting

  before do
    unless request.fullpath.include?('access_tokens')
      halt 401 if current_token.nil?
      halt 403 if current_token.banned?
    end
  end

  error do
    logger.error env['sinatra.error'].message
    logger.error env['sinatra.error'].backtrace.first

    halt 400
  end

  post '/access_tokens/new' do
    json token: TemporaryToken.create.token
  end

  post '/access_tokens' do
    if TemporaryToken.validate! params[:access_token][:token]
      json token: AccessToken.create.token
    else
      halt 403
    end
  end

  get '/chains' do
    json chains: Chain.all.to_a.shuffle.map(&:to_h)
  end

  get '/chains/:chain_id' do
    json chain: Chain.find(params[:chain_id]).to_h
  end

  get '/codes/:code/chain' do
    json chain: (Chain.find_by(code: params[:code]) rescue nil).to_h
  end

  post '/chains' do
    chain = Chain.create

    if upload[:tempfile]
      data, time = process_sound upload[:tempfile], upload[:type]

      chain.destroy and halt 422 if data.nil? || data.size == 0 || time.nil? || time > 30

      path = upload_to_s3 'sounds', data, time

      chain.add_sound url: path, duration: time, visible: true

      chain.inc queued_build_count: 1 if Qu.enqueue BuildAudio, chain.id.to_s
    end

    json chain: chain.to_h
  end

  post '/chains/:chain_id/sounds' do
    chain = Chain.find params[:chain_id]

    data, time = process_sound upload[:tempfile], upload[:type]

    halt 422 if data.nil? || data.size == 0 || time.nil? || time > 30

    path = upload_to_s3 'sounds', data, time

    sound = chain.add_sound url: path, duration: time

    chain.inc queued_build_count: 1 if Qu.enqueue BuildAudio, chain.id.to_s, [sound.id.to_s]

    json chain: chain.to_h
  end

  post '/chains/:chain_id/sounds/:sound_id/toggle' do
    chain = Chain.find params[:chain_id]

    sound = chain.sounds.find params[:sound_id]

    sound.update included: !sound.included

    chain.inc queued_build_count: 1 if Qu.enqueue BuildAudio, chain.id.to_s

    json chain: chain.to_h
  end
end
