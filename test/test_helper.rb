require 'bundler/setup'

require 'minitest/autorun'
require 'minitest/pride'

require File.join(File.dirname(__FILE__), *%w{ .. lib db_morph })
