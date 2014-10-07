module PgMorph

  module Adapter

    def add_polymorphic_foreign_key(from_table, to_table, options = {})
      raise_unless_postgres

      polymorphic = PgMorph::Polymorphic.new(from_table, to_table, options)
      raise PgMorph::Exception.new("Column not specified") unless polymorphic.column_name

      sql = polymorphic.create_child_table_sql
      sql << polymorphic.create_before_insert_trigger_fun_sql
      sql << polymorphic.create_before_insert_trigger_sql
      sql << polymorphic.create_after_insert_trigger_fun_sql
      sql << polymorphic.create_after_insert_trigger_sql

      execute(sql)
    end

    def remove_polymorphic_foreign_key(from_table, to_table, options = {})
      raise_unless_postgres

      polymorphic = PgMorph::Polymorphic.new(from_table, to_table, options)
      raise PgMorph::Exception.new("Column not specified") unless polymorphic.column_name

      sql = polymorphic.remove_before_insert_trigger_sql
      sql << polymorphic.remove_partition_table
      sql << polymorphic.remove_after_insert_trigger_sql

      execute(sql)
    end

    private

    def raise_unless_postgres
      raise PgMorph::Exception.new("This functionality is supported only by PostgreSQL") unless self.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    end

  end

end
