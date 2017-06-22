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

  Mongoid.configure do |config|
    config.raise_not_found_error = false
  end

  Qu.backend = Qu::Backend::Mongoid.new

  helpers Interesting

  before do
    halt 401 unless current_token
  end

  error do
    logger.error env['sinatra.error'].message
    logger.error env['sinatra.error'].backtrace.first

    halt 400, json(error: 'sorry, something went wrong')
  end

  post '/access_tokens/new' do
    temporary_token = TemporaryToken.create

    json token: temporary_token.token
  end

  post '/access_tokens' do
    if TemporaryToken.validate! params[:token]
      access_token = AccessToken.create

      render token: access_token.token
    else
      halt 401
    end
  end

  get '/chains' do
    res = if params[:chain_ids].nil?
            Chain.all.to_a.shuffle.map(&:to_h)
          else
            params[:chain_ids].map { |chain_id| Chain.find chain_id }.map(&:to_h)
          end

    json chains: res
  end

  get '/chains/:chain_id' do
    chain = Chain.find params[:chain_id]

    json chain: chain.to_h
  end

  post '/chains' do
    chain = Chain.create

    if upload[:tempfile]
      data, time = process_sound upload[:tempfile], upload[:type]

      path = upload_to_s3 'sounds', data, time

      chain.add_sound url: path, duration: time, visible: true

      chain.inc queued_build_count: 1 if Qu.enqueue BuildAudio, chain.id.to_s
    end

    json chain: chain.to_h
  end

  post '/chains/:chain_id/sounds' do
    chain = Chain.find params[:chain_id]

    data, time = process_sound upload[:tempfile], upload[:type]

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