require 'rake/testtask'

task default: :test

spec = Gem::Specification.load('minitest-proptest.gemspec')

Rake::TestTask.new(:test) do |t|
	t.libs.unshift File.expand_path('../test', __FILE__)
  t.test_files = Dir.glob('test/**/*_test.rb')
	t.ruby_opts << '-I./lib'
end
