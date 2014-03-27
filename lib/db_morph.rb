require 'bundler/setup'
Bundler.require :default, :test

require 'active_support'
require 'active_record'

require File.join(File.dirname(__FILE__), %w{ db_morph adapter })

module DbMorph
end

require File.join(File.dirname(__FILE__), %w{ db_morph railtie }) if defined?(Rails)
