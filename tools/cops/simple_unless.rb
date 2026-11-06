require "rubocop"

module RuboCop
  module Cop
    module Spinelcraft
      # An `unless` takes one simple condition. With `&&`, `||`, a negation
      # or a ternary, the reader must flip each part in the head. The
      # built-in cops miss a condition in parentheses.
      class SimpleUnless < Base
        MSG = "Give `unless` one simple condition: write an `if`, or one guard for each part."

        def on_if(node)
          return unless node.unless?

          add_offense(node) if compound?(bare(node.condition))
        end

        private

        def bare(condition)
          condition = condition.children.last while condition.begin_type?
          condition
        end

        def compound?(condition)
          return true if condition.operator_keyword?
          return true if condition.if_type?

          condition.send_type? && condition.method?(:!)
        end
      end
    end
  end
end
