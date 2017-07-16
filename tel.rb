require 'mongoid'
require 'pry'
require 'qu'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader' if development?

require_relative './models/qu/backend/mongoid'

Dir['./models/*.rb'].each { |file| require_relative file }

class Tel < Sinatra::Base
  set :show_exceptions => false
  set :raise_errors => false

  Mongoid.load! 'mongoid.yml'

  Qu.backend = Qu::Backend::Mongoid.new

  helpers Interesting

  before do
    unless request.fullpath.include?('access_tokens') || request.fullpath == '/'
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
    if TemporaryToken.validate! params[:token]
      json token: AccessToken.create.token
    else
      halt 403
    end
  end

  get '/' do
    "hello darkness my old friend"
  end

  get '/chains' do
    # limit = 20
    # page = params[:page] || 1
    # offset = (page - 1) * limit
    # pages = (Chain.count / limit.to_f).ceil
    #
    # json pages: pages, chains: Chain.order_by(created_at: :desc).offset(offset).limit(limit).map { |c| c.to_h(current_token.starred) }

    halt 400 if params[:chain_ids].nil? || params[:chain_ids].empty?

    json chains: Chain.find(params[:chain_ids]).sort_by { |c| params[:chain_ids].index(c.id.to_s) }.map { |c| c.to_h(current_token.starred) }
  end

  get '/chains/random' do
    json chains: (0..Chain.count-1).sort_by{ rand }.slice(0,10).map { |i| Chain.skip(i).first.to_h(current_token.starred) }
  end

  get '/chains/:chain_id' do
    json chain: (Chain.find(params[:chain_id]).to_h(current_token.starred) rescue nil)
  end

  get '/codes/:code/chain' do
    json chain: (Chain.find_by(code: params[:code]).to_h(current_token.starred) rescue nil)
  end

  post '/chains' do
    chain = Chain.create

    if upload[:tempfile]
      data, time = process_sound upload[:tempfile], upload[:type]

      chain.destroy and halt 422 unless (1..16).cover? time

      path = upload_to_s3 'sounds', data, time

      chain.add_sound url: path, duration: time, visible: true

      data, time = combine_sounds chain.included_sounds

      path = upload_to_s3 'chains', data, time, chain.url

      chain.update(url: path, duration: time) if path
    end

    json chain: chain.to_h(current_token.starred)
  end

  post '/chains/:chain_id/sounds' do
    chain = Chain.find params[:chain_id]

    data, time = process_sound upload[:tempfile], upload[:type]

    halt 422 unless (1..16).cover? time

    path = upload_to_s3 'sounds', data, time

    sound = chain.add_sound url: path, duration: time

    chain.inc queued_build_count: 1 if Qu.enqueue BuildAudio, chain.id.to_s, [sound.id.to_s]

    json chain: chain.to_h(current_token.starred)
  end

  post '/chains/:chain_id/sounds/:sound_id/toggle' do
    chain = Chain.find params[:chain_id]

    sound = chain.sounds.find params[:sound_id]

    sound.update included: !sound.included

    chain.inc queued_build_count: 1 if Qu.enqueue BuildAudio, chain.id.to_s

    json chain: chain.to_h(current_token.starred)
  end

  get '/starred' do
    json chains: Chain.find(current_token.starred).map { |c| c.to_h(current_token.starred)}
  end

  post '/starred' do
    halt 422 if params[:chain_id].nil? || (Chain.find(params[:chain_id]) rescue nil).nil?

    if current_token.starred.include? params[:chain_id]
      current_token.starred.delete params[:chain_id]
    else
      current_token.starred.push params[:chain_id]
    end

    current_token.save

    json chain: Chain.find(params[:chain_id]).to_h(current_token.starred)
  end
end
