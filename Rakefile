require "minitest/test_task"

# `rake test` runs the tests in test/ under CRuby, with no build.
Minitest::TestTask.create

desc "Run RuboCop and Reek"
task :lint do
  sh "mise exec -- rubocop"
  sh "mise exec -- reek main.rb game tools"
end

task default: %i[lint test]
