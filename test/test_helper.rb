# frozen_string_literal: true

require 'minitest'
require 'minitest/proptest'
require 'minitest/autorun'

# Needed as of Minitest 6.0
Minitest.load :proptest if Minitest.respond_to?(:load)
