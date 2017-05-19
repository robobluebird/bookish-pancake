module Auth
  module ::Sinatra
    class Request
      def authorization
        @authorization_header ||= begin
          Sinatra::HeaderField::Authorization.new self.env['HTTP_AUTHORIZATION']
        end
      end
    end

    module HeaderField
      class Authorization
        attr_accessor :type, :key, :value

        def initialize(auth_str)
          return if auth_str.nil?

          arr = auth_str.strip.split /\s+/i

          if arr.count == 2
            @type = arr[0]
            @key, @value = parse_auth_pair arr[1]
          end
        end

        def parse_auth_pair(pair_str)
          pair = pair_str.split '='

          if pair.count == 2
            pair
          else
            [nil, nil]
          end
        end
      end
    end
  end

  def current_account
    @current_account ||= Account.find_by api_key: request.authorization.value
  end

  def current_creator
    @current_creator ||= Creator.new_with_account(current_account) if current_account
  end
end