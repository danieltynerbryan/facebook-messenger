module Facebook
  module Messenger
    module Concerns
      # The Common options for incoming optin and postback.
      module DefaultOptions
        attr_reader :messaging

        def initialize(messaging)
          @messaging = messaging
        end

        def sender
          @messaging['sender']
        end

        def recipient
          @messaging['recipient']
        end

        def sent_at
          Time.at(@messaging['timestamp'] / 1000)
        end
      end
    end
  end
end
