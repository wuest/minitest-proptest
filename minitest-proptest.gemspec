# frozen_string_literal: true

require_relative 'lib/minitest/proptest/version'

Gem::Specification.new do |s|
  s.name = 'minitest-proptest'
  s.version = Minitest::Proptest::VERSION

  s.description = "Property testing in Minitest, a la Haskell's QuickCheck and Python's Hypothesis"
  s.summary     = 'Property testing in Minitest'
  s.authors     = ['Tina Wuest']
  s.email       = 'tina@wuest.me'
  s.homepage    = 'https://github.com/wuest/minitest-proptest'
  s.license     = 'MIT'

  s.required_ruby_version = '>= 2.7.0'

  s.metadata['homepage_uri'] = s.homepage
  s.metadata['source_code_uri'] = s.homepage
  s.metadata['changelog_uri'] = 'https://github.com/wuest/minitest-proptest/blob/main/CHANGELOG.md'

  s.files = `git ls-files ext`.split("\n")

  s.add_dependency 'minitest', '~> 5'
end
