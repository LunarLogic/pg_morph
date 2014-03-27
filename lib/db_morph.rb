require 'active_support'

require File.join(File.dirname(__FILE__), %w{ db_morph adapter })

module DbMorph
end

require File.join(File.dirname(__FILE__), %w{ db_morph railtie }) if defined?(Rails)
