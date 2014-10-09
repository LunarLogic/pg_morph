# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pg_morph/version'

Gem::Specification.new do |spec|
  spec.name          = "pg_morph"
  spec.version       = PgMorph::VERSION
  spec.authors       = ["Hanka"]
  spec.email         = ["hanka@lunarlogic.io"]
  spec.summary       = %q{Takes care of postgres DB consistency for ActiveRecord polymorphic associations via partitioning and inheritance}
  spec.homepage      = "http://github.com/LunarLogic/pg-morph"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 3.0.0"

  spec.add_development_dependency "rails", ">= 3.0.0"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "mocha"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "colored"
  spec.add_development_dependency "awesome_print"
end
