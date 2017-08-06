require 'mongoid'
require './models/circle'
require './models/sound'
ENV['RACK_ENV'] = 'development' if ENV['RACK_ENV'].nil?
Mongoid.load! 'mongoid.yml'
