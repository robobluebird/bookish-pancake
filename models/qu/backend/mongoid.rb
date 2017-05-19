require 'mongoid'
require 'qu'

module Qu
  module Backend
    class Mongoid < Base
      attr_accessor :max_retries
      attr_accessor :retry_frequency
      attr_accessor :poll_frequency

      def self.length(queue = 'default')
        jobs(queue).count
      end

      def initialize
        self.max_retries = 5
        self.retry_frequency = 1
        self.poll_frequency  = 5
      end

      def connection
        @connection ||= begin
          raise 'Mongoid not configured!' unless ::Mongoid.configured?
          ::Mongoid.default_client
        end
      end

      def connection=(connection)
        @connection = connection
      end

      def clear(queue = nil)
        queue ||= queues + ['failed']

        logger.info { "Clearing queues: #{queue.inspect}" }

        Array(queue).each do |q|
          logger.debug "Clearing queue #{q}"

          jobs(q).drop

          self[:queues].delete_one(:name => q)
        end
      end

      def queues
        self[:queues].find.map {|doc| doc['name'] }
      end

      def length(queue = 'default')
        jobs(queue).count
      end

      def enqueue(payload)
        payload.id = BSON::ObjectId.new

        jobs(payload.queue).insert_one(:id => payload.id, :klass => payload.klass.to_s, :args => payload.args)

        self[:queues].update_one({:name => payload.queue}, {:name => payload.queue}, :upsert => true)

        logger.debug { "Enqueued job #{payload}" }

        payload
      end

      def reserve(worker, options = {:block => true})
        loop do
          worker.queues.each do |queue|
            logger.debug { "Reserving job in queue #{queue}" }

            if doc = jobs(queue).find_one_and_delete({})
              return Payload.new(doc)
            end
          end

          if options[:block]
            sleep poll_frequency
          else
            break
          end
        end
      end

      def release(payload)
        jobs(payload.queue).insert_one(:_id => payload.id, :klass => payload.klass.to_s, :args => payload.args)
      end

      def failed(payload, error)
        jobs('failed').insert_one(:_id => payload.id, :klass => payload.klass.to_s, :args => payload.args, :queue => payload.queue)
      end

      def completed(payload)
        logger.debug "Completed job #{payload}"
      end

      def register_worker(worker)
        logger.debug "Registering worker #{worker.id}"
        self[:workers].insert_one(worker.attributes.merge(:id => worker.id))
      end

      def unregister_worker(worker)
        logger.debug "Unregistering worker #{worker.id}"
        self[:workers].delete_one(:id => worker.id)
      end

      def workers
        self[:workers].find.map do |doc|
          Qu::Worker.new(doc)
        end
      end

      def clear_workers
        logger.info 'Clearing workers'
        self[:workers].drop
      end

      private

      def jobs(queue)
        self["queue:#{queue}"]
      end

      def [](name)
        rescue_connection_failure do
          connection["qu:#{name}"]
        end
      end

      def rescue_connection_failure
        retries = 0
        begin
          yield
        rescue ::Mongoid::Errors::MongoidError
          retries += 1
          raise ex if retries > max_retries
          sleep retry_frequency * retries
          retry
        end
      end
    end
  end
end