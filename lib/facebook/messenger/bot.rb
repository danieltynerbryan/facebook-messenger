module Facebook
  module Messenger
    # The Bot module sends and receives messages.
    module Bot
      include HTTParty
      debug_output $stdout

      base_uri 'https://graph.facebook.com/v2.6/me'

      EVENTS = [:message, :delivery, :postback, :optin,
                :read, :account_linking, :referral].freeze

      class << self
        # Deliver a message with the given payload.
        #
        # message - A Hash describing the recipient and the message*.
        #
        # * https://developers.facebook.com/docs/messenger-platform/send-api-reference#request
        #
        # Returns a String describing the message ID if the message was sent,
        # or raises an exception if it was not.
        def for_uri(uri)
          current_uri = self.base_uri
          self.base_uri uri
          yield
          self.base_uri current_uri
        end

        def deliver(message)
          response = post '/messages', body: JSON.dump(message), format: :json

          raise_errors_from(response)

          response['message_id']
        end

        def custom_label(name:)
          response = post '/custom_labels', body: JSON.dump({"name" => name}), format: :json

          raise_errors_from(response)

          response['id']
        end

        def add_user_to_label(label_id:, user_id:)
          success = false
          for_uri('https://graph.facebook.com/v2.6') do
            response = post "/#{label_id}/label", body: JSON.dump({"user" => user_id}), format: :json

            raise_errors_from(response)

            success = response['success']
          end

          success
        end

        def message_creatives(message_object:)
          response = post '/message_creatives', body: JSON.dump({"messages" => [message_object]}), format: :json

          raise_errors_from(response)

          response['message_creative_id']
        end

        def broadcast(message_id:, label_id:)
          response = post '/broadcast_messages', body: JSON.dump({"message_creative_id" => message_id, "custom_label_id" => label_id}), format: :json

          raise_errors_from(response)

          response['broadcast_id']
        end

        # Register a hook for the given event.
        #
        # event - A String describing a Messenger event.
        # block - A code block to run upon the event.
        def on(event, &block)
          unless EVENTS.include? event
            raise ArgumentError,
                  "#{event} is not a valid event; " \
                  "available events are #{EVENTS.join(',')}"
          end

          hooks[event] = block
        end

        # Receive a given message from Messenger.
        #
        # payload - A Hash describing the message.
        #
        # * https://developers.facebook.com/docs/messenger-platform/webhook-reference
        def receive(payload)
          callback = Facebook::Messenger::Incoming.parse(payload)
          event = Facebook::Messenger::Incoming::EVENTS.invert[callback.class]
          trigger(event.to_sym, callback)
        end

        # Trigger the hook for the given event.
        #
        # event - A String describing a Messenger event.
        # args - Arguments to pass to the hook.
        def trigger(event, *args)
          hooks.fetch(event).call(*args)
        rescue KeyError
          $stderr.puts "Ignoring #{event} (no hook registered)"
        end

        # Raise any errors in the given response.
        #
        # response - A HTTParty::Response object.
        #
        # Returns nil if no errors were found, otherwises raises appropriately.
        def raise_errors_from(response)
          return unless response.key? 'error'
          error = response['error']

          raise(
            error_class_from_error_code(error['code']),
            (error['error_data'] || error['message'])
          )
        end

        # Find the appropriate error class for the given error code.
        #
        # error_code - An Integer describing an error code.
        #
        # Returns an error class, or raises KeyError if none was found.
        def error_class_from_error_code(error_code)
          {
            100 => RecipientNotFound,
            10 => PermissionDenied,
            2 => InternalError
          }[error_code] || Facebook::Messenger::Error
        end

        # Return a Hash of hooks.
        def hooks
          @hooks ||= {}
        end

        # Deregister all hooks.
        def unhook
          @hooks = {}
        end

        # Default HTTParty options.
        def default_options
          super.merge(
            query: {
              access_token: Facebook::Messenger.config.access_token
            },
            headers: {
              'Content-Type' => 'application/json'
            }
          )
        end
      end

      class RecipientNotFound < Facebook::Messenger::Error; end
      class PermissionDenied < Facebook::Messenger::Error; end
      class InternalError < Facebook::Messenger::Error; end
    end
  end
end
