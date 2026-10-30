require "rubocop"

module RuboCop
  module Cop
    module Spinelcraft
      # Only Weather compares the strength of the rain. The fire rules had
      # one test each, and in the first seconds of rain they disagreed.
      # Other code can scale a color or a sound by the strength.
      class RainStrength < Base
        MSG = "Use Weather#wet_at? or Spell#on?: only Weather compares the strength of the rain."
        RESTRICT_ON_SEND = %i[> >= < <= == !=].freeze

        # @!method rain?(node)
        def_node_matcher :rain?, "(send (send _ :rain) :strength)"

        def on_send(node)
          add_offense(node) if rain?(node.receiver) || rain?(node.first_argument)
        end
      end
    end
  end
end
