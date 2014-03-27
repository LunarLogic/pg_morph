module DbMorph
  class Railtie < Rails::Railtie
    initializer 'DbMorph.active_record' do
      ActiveSupport.on_load :active_record do
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
          include DbMorph::Adapter
        end
      end
    end
  end
end
