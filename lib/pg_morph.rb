require 'bundler/setup'
Bundler.require :default, :test

require 'active_support'
require 'active_record'

require File.join(File.dirname(__FILE__), %w{ pg_morph adapter })
require File.join(File.dirname(__FILE__), %w{ pg_morph naming })
require File.join(File.dirname(__FILE__), %w{ pg_morph polymorphic })

require File.join(File.dirname(__FILE__), %w{ pg_morph railtie }) if defined?(Rails)

module PgMorph
  class Exception < RuntimeError
  end
end
