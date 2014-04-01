require 'pg_morph'
require 'dummy/config/environment'
require 'mocha'
require 'pry'

require 'minitest/autorun'
require 'minitest/pride'

require File.join(File.dirname(__FILE__), *%w{ .. lib pg_morph })

module PgMorph
  class UnitTest < ActiveSupport::TestCase
  end
end
