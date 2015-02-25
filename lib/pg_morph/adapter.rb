module PgMorph

  module Adapter

    def add_polymorphic_foreign_key(parent_table, child_table, options = {})
      raise_unless_postgres

      polymorphic = PgMorph::Polymorphic.new(parent_table, child_table, options)

      sql =  polymorphic.rename_base_table_sql
      sql << polymorphic.create_base_table_view_sql
      sql << polymorphic.create_proxy_table_sql
      sql << polymorphic.create_before_insert_trigger_fun_sql
      sql << polymorphic.create_before_insert_trigger_sql

      execute(sql)
    end

    def remove_polymorphic_foreign_key(parent_table, child_table, options = {})
      raise_unless_postgres

      polymorphic = PgMorph::Polymorphic.new(parent_table, child_table, options)

      sql = polymorphic.remove_before_insert_trigger_sql
      sql << polymorphic.remove_proxy_table

      execute(sql)
    end

    private

    def raise_unless_postgres
      raise PgMorph::Exception.new("This functionality is supported only by PostgreSQL") unless self.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    end

  end

end
