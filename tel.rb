require 'mongoid'
require 'qu'
require_relative './models/qu/backend/mongoid'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/reloader' if development?

Dir['./models/*.rb'].each { |file| require file }

set :show_exceptions => false
set :raise_errors => false

Mongoid.load! 'mongoid.yml'

Mongoid.configure do |config|
  config.raise_not_found_error = false
end

Qu.backend = Qu::Backend::Mongoid.new

class TelError
  attr_accessor :errors

  def initialize
    @errors = []
  end

  def <<(error)
    add error
  end

  def add error
    errors << error
  end
end

helpers Interesting

helpers do
  def errors
    @errors ||= TelError.new
  end
end

before do
  # if request.fullpath == '/accounts'
  #   raise 'bad signup request' unless valid_new_handle? && signup_code.present?
  # else
  #   raise 'need an account for any of this!' if current_account.nil?
  # end
end

error do
  logger.error env['sinatra.error'].message
  logger.error env['sinatra.error'].backtrace.first

  halt 400, json(error: 'sorry, something went wrong')
end

get '/' do
  [200, {}, ['YOUR LIFE IS A LIE']]
end

post '/accounts' do
  json account: Account.create!(api_key: SecureRandom.uuid, handle: params[:handle]).to_h
end

put '/accounts/:account_id' do
  account = Account.find params[:account_id]
  account.update! handle: params[:handle]
  json account: account.to_h
end

get '/chains' do
  # json chains: Chain.all.to_a.shuffle.map(&:to_h)
  json chains: [
    {
      id: BSON::ObjectId.new.to_s,
      description: 'some weird thing',
      url: 'https://s3.us-east-2.amazonaws.com/tel-serv/sounds/2017-04-15/zach/1492301137.mp3',
      duration: 22.012,
      sounds: [
        {
          id: BSON::ObjectId.new.to_s,
          url: 'bep',
          duration: 6.2,
          position: 1,
        },
        {
          id: BSON::ObjectId.new.to_s,
          url: 'bep',
          duration: 7.8,
          position: 6,
        },
        {
          id: BSON::ObjectId.new.to_s,
          url: 'bep',
          duration: 8.012,
          position: 9,
        }
      ]
    },
    {
      id: BSON::ObjectId.new.to_s,
      description: 'some other weird thing',
      url: nil,
      duration: nil,
      sounds: []
    },
    {
      id: BSON::ObjectId.new.to_s,
      description: 'yawt',
      url: 'https://s3.us-east-2.amazonaws.com/tel-serv/sounds/2017-04-15/zach/1492301137.mp3',
      duration: 22.012,
      sounds: [
        {
          id: BSON::ObjectId.new.to_s,
          url: 'krebs',
          duration: 7.8,
          position: 2,
        },
        {
          id: BSON::ObjectId.new.to_s,
          url: 'krebs',
          duration: 4.7,
          position: 3,
        },
        {
          id: BSON::ObjectId.new.to_s,
          url: 'krebs',
          duration: 6.92,
          position: 5,
        },
        {
          id: BSON::ObjectId.new.to_s,
          url: 'krebs',
          duration: 2.592,
          position: 14,
        }
      ]
    }
  ]
end

=begin
      id: id.to_s,
      description: description,
      url: url,
      duration: duration,
      creator: creator.to_h,
      sounds: included_sounds.map(&:to_h)

      id: id.to_s,
      url: url,
      duration: duration,
      position: position,
      creator: creator.to_h
=end

get '/chains/:chain_id' do
  chain = Chain.find params[:chain_id]

  json chain: chain.to_h
end

post '/chains' do
  chain = Chain.create! description: params[:description] # , account: current_account, creator: current_creator

  if upload[:tempfile]
    data, time = process_sound(upload[:tempfile], upload[:type])

    path = upload_to_s3('sounds', data, time)

    chain.add_sound! url: path, duration: time

    Qu.enqueue BuildAudio, chain.id.to_s
  end

  json chain: chain.to_h
end

post '/chains/:chain_id/sounds' do
  chain = Chain.find_by(_id: params[:chain_id])

  data, time = process_sound upload[:tempfile], upload[:type]

  path = upload_to_s3('sounds', data, time)

  prepend = params[:prepend_id] # if current_account.id == chain.creator.id

  chain.add_sound! before: prepend, url: path, duration: time

  data, time = combine_sounds(chain)

  path = upload_to_s3 'chains', data, time, chain.url

  chain.update!(url: path)

  json chain: chain.to_h
end

post '/chains/:chain_id/build' do

end

post '/chains/:chain_id/sounds/:sound_id/toggle' do
  chain = Chain.find_by id: params[:chain_id]

  # raise 'tsk tsk' if chain.creator.account_id != current_account.id.to_s

  sound = chain.sounds.find_by id: params[:sound_id]

  sound.update! included: !sound.included

  data, time = combine_sounds chain.included_sounds

  path = upload_to_s3 'chains', data, time, chain.url

  chain.update!(url: path, duration: time)

  json chain: chain.to_h
end

post '/chains/:chain_id/sounds/:sound_id/delete' do
  chain = Chain.find id: params[:chain_id]

  # raise 'tsk tsk' if chain.creator.account_id != current_account.id.to_s

  sound = chain.sounds.find id: params[:sound_id]

  sound.update! visible: !sound.visible

  json  chain: chain.to_h
end
