require 'factory_girl'

FactoryGirl.define do
  factory :temporary_code do
    code nil
  end

  factory :z_code do
    code 'wat'
  end

  factory :creator do
    handle 'peep'
  end

  factory :account do
    handle 'zach'
    api_key 'musubi'
  end

  factory :sound do
    position 0
    duration 0
    url nil
    included false
  end

  factory :chain do
    description 'hello'
  end
end
