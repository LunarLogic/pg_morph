require 'pg_morph'
require 'active_record/connection_adapters/postgresql_adapter'
require 'dummy/config/environment'
require 'mocha'
require 'pry'

require 'minitest/autorun'
require 'minitest/pride'

require File.expand_path("../dummy/config/environment.rb", __FILE__)
require File.join(File.dirname(__FILE__), *%w{ .. lib pg_morph })

module PgMorph
  class UnitTest < ActiveSupport::TestCase
  end
end
