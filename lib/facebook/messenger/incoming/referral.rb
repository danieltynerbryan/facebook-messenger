module Facebook
  module Messenger
    module Incoming
      # The Referral class represents an incoming Facebook Messenger referral.
      class Referral
        attr_reader :messaging

        def initialize(referral)
          @referral = referral
        end

        def ref
          @referral['ref']
        end

        def source
          @referral['source']
        end

        def type
          @referral['type']
        end
      end
    end
  end
end