# frozen_string_literal: true

require 'rake/testtask'

task default: :test

Rake::TestTask.new(:fails) do |t|
  t.libs.unshift File.expand_path('test', __dir__)
  t.libs.unshift File.expand_path('lib', __dir__)
  t.test_files = Dir.glob('test/should_fail/**/*_fails.rb')
end

Rake::TestTask.new(:test) do |t|
  t.libs.unshift File.expand_path('test', __dir__)
  t.libs.unshift File.expand_path('lib', __dir__)
  t.test_files = Dir.glob('test/**/*_test.rb')
end
