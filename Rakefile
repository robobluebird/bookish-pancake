require 'qu'
require 'mongoid'
require 'qu/tasks'
require_relative './models/qu/backend/mongoid'
require_relative './models/build_audio'

Mongoid.load! 'mongoid.yml'

Qu.backend = Qu::Backend::Mongoid.new