require "rubocop"

module RuboCop
  module Cop
    module Spinelcraft
      # Only Clock turns the time of day into ticks. A literal 24000 in
      # other code makes a second conversion, and the two can disagree.
      # Light.sky had one, and /time set showed the wrong tick.
      class DayTicks < Base
        MSG = "Use Clock::DAY_TICKS or Clock#ticks: only Clock turns the time of day into ticks."
        # Clock::DAY_TICKS. RuboCop does not load the game.
        DAY_TICKS = 24000

        def on_int(node) = check(node)
        def on_float(node) = check(node)

        private

        def check(node)
          add_offense(node) if node.value == DAY_TICKS
        end
      end
    end
  end
end
