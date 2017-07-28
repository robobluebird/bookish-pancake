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

  helpers do
    def circle
      @circle ||= Circle.find params[:circle_id]
    end

    def sound
      @sound ||= circle.sounds.find params[:sound_id]
    end
  end

  before do
    unless request.fullpath.include?('access_tokens') || request.fullpath == '/'
      halt 500 if request.env['HTTP_USER_AGENT'] !~ /Alamofire/

      if current_token.nil?
        if !request.authorization.value.nil?
          @current_token = AccessToken.create(token: request.authorization.value)

          halt 401 if current_token.nil?
        else
          halt 401
        end
      end

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

  get '/circles' do
    # limit = 20
    # page = params[:page] || 1
    # offset = (page - 1) * limit
    # pages = (Circle.count / limit.to_f).ceil
    #
    # json pages: pages, circles: Circle.order_by(created_at: :desc).offset(offset).limit(limit).map { |c| c.to_h(current_token.starred) }

    halt 400 if params[:circle_ids].nil? || params[:circle_ids].empty?

    json circles: Circle.visible
      .where(:_id.in => params[:circle_ids])
      .sort_by { |c| params[:circle_ids].index(c.id.to_s) }
      .map { |c| c.to_h(current_token.starred) }
  end

  get '/circles/random' do
    json circles: (0..Circle.visible.count - 1)
      .sort_by { rand }
      .slice(0,10)
      .map { |i| Circle.visible.skip(i).first.to_h(current_token.starred) }
  end

  get '/circles/:circle_id' do
    json circle: (Circle.find(params[:circle_id]).to_h(current_token.starred) rescue nil)
  end

  get '/codes/:code/circle' do
    json circle: (Circle.find_by(code: params[:code]).to_h(current_token.starred) rescue nil)
  end

  post '/circles' do
    circle = Circle.create token: current_token.token

    if upload[:tempfile]
      data, time = process_sound upload[:tempfile], upload[:type]

      circle.destroy and halt 422 unless (1..16).cover? time

      path = upload_to_s3 'sounds', data, time

      circle.add_sound url: path, duration: time, visible: true, token: current_token.token

      data, time = combine_sounds circle.included_sounds

      path = upload_to_s3 'circles', data, time, circle.url

      circle.update(url: path, duration: time) if path
    end

    json circles: Circle.visible
      .where(token: current_token.token)
      .order(created_at: :desc)
      .map { |c| c.to_h(current_token.starred) }
  end

  post '/circles/:circle_id/sounds' do
    circle = Circle.find params[:circle_id]

    data, time = process_sound upload[:tempfile], upload[:type]

    halt 422 unless (1..16).cover? time

    path = upload_to_s3 'sounds', data, time

    sound = circle.add_sound url: path, duration: time, visible: false, token: current_token.token

    circle.inc queued_build_count: 1 if Qu.enqueue BuildAudio, circle.id.to_s, [sound.id.to_s]

    json circle: circle.to_h(current_token.starred)
  end

  post '/circles/:circle_id/hide' do
    circle = Circle.find params[:circle_id]

    circle.update visible: false

    json circle: circle.to_h(current_token.starred), hidden: true
  end

  post '/circles/:circle_id/sounds/:sound_id/hide' do
    circle = Circle.find params[:circle_id]

    sound = circle.sounds.find params[:sound_id]

    if circle.included_sounds.count <= 1
      circle.update visible: false

      json circle: circle.to_h(current_token.starred), hidden: true
    else
      sound.update included: false

      circle.inc queued_build_count: 1 if Qu.enqueue BuildAudio, circle.id.to_s, nil, [sound.id.to_s]

      json circle: circle.to_h(current_token.starred)
    end
  end

  get '/created' do
    json circles: Circle.visible
      .where(token: current_token.token)
      .order(created_at: :desc)
      .map { |c| c.to_h(current_token.starred) }
  end

  get '/starred' do
    json circles: Circle.visible
      .where(:_id.in => current_token.starred)
      .map { |c| c.to_h(current_token.starred) }
  end

  post '/starred' do
    halt 422 if params[:circle_id].nil? || (Circle.find(params[:circle_id]) rescue nil).nil?

    if current_token.starred.include? params[:circle_id]
      current_token.starred.delete params[:circle_id]
    else
      current_token.starred.push params[:circle_id]
    end

    current_token.save

    json circle: Circle.find(params[:circle_id]).to_h(current_token.starred)
  end
end
