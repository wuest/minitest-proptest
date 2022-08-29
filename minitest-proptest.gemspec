Gem::Specification.new do |s|
  s.name = 'minitest-proptest'
  s.version = '0.0.1'

  s.description = 'Property testing in Minitest, with shrinker inspired by DRMaciver\'s Minithesis/Hypothesis'
  s.summary     = 'Property testing in Minitest'
  s.authors     = ['Tina Wuest']
  s.email       = 'tina@wuest.me'
  s.homepage    = 'https://gitlab.com/wuest/minitest-proptest'

  s.files = `git ls-files ext`.split("\n")

  s.add_development_dependency 'minitest', '~> 5'
end
