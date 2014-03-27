p 1

module DbMorph
  p 2
  class Railtie < Rails::Railtie
    p 3
    initializer 'DbMorph.active_record' do
      ActiveSupport.on_load :active_record do
        p 'railtie??'
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
          p 'include'
          include DbMorph::Adapter
        end
      end
    end
  end
end
