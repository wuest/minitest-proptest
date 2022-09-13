require 'rake/testtask'

task default: :test

spec = Gem::Specification.load('minitest-proptest.gemspec')

Rake::TestTask.new(:fails) do |t|
	t.libs.unshift File.expand_path('../test', __FILE__)
	t.libs.unshift File.expand_path('../lib', __FILE__)
  t.test_files = Dir.glob('test/should_fail/**/*_fails.rb')
end

Rake::TestTask.new(:test) do |t|
	t.libs.unshift File.expand_path('../test', __FILE__)
	t.libs.unshift File.expand_path('../lib', __FILE__)
  t.test_files = Dir.glob('test/**/*_test.rb')
end
