module PgMorph

  module Adapter

    def add_polymorphic_foreign_key(from_table, to_table, options = {})
      raise_unless_postgres

      polymorphic = PgMorph::Polymorphic.new(from_table, to_table, options)
      raise "Column not specified" unless polymorphic.column_name

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
      raise "Column not specified" unless polymorphic.column_name

      sql = remove_before_insert_trigger_sql(polymorphic)

      sql << remove_partition_table(polymorphic)

      sql << remove_after_insert_trigger_sql(polymorphic)

      execute(sql)
    end

    def remove_partition_table(polymorphic)
      table_empty = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{polymorphic.from_table}_#{polymorphic.to_table}").to_i.zero?
      if table_empty
        %Q{ DROP TABLE IF EXISTS #{polymorphic.child_table}; }
      else
        raise PG::Error.new("Partition table #{polymorphic.child_table} contains data.\nRemove them before if you want to drop that table.\n")
      end
    end

    def remove_before_insert_trigger_sql(polymorphic)
      trigger_name = polymorphic.before_insert_trigger_name
      fun_name = polymorphic.before_insert_fun_name

      prosrc = get_function(fun_name)
      raise PG::Error.new("There is no such function #{fun_name}()\n") unless prosrc

      scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
      cleared = scan.reject { |x| x[0].match("#{polymorphic.child_table}") }

      if cleared.present?
        cleared[0][0].sub!('ELSIF', 'IF')
        polymorphic.before_insert_trigger_content do
          cleared.map { |m| m[0] }.join('').strip
        end
      else
        drop_trigger_and_fun_sql(trigger_name, polymorphic.from_table, fun_name)
      end
    end

    def remove_after_insert_trigger_sql(polymorphic)
      prosrc = get_function(polymorphic.before_insert_fun_name)
      scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
      cleared = scan.reject { |x| x[0].match("#{polymorphic.child_table}") }

      return '' if cleared.present?
      fun_name = polymorphic.after_insert_fun_name
      trigger_name = polymorphic.after_insert_trigger_name

      drop_trigger_and_fun_sql(trigger_name, polymorphic.from_table, fun_name)
    end

    def get_function(fun_name)
      run("SELECT prosrc FROM pg_proc WHERE proname = '#{fun_name}'")
    end

    private

    def run(query)
      ActiveRecord::Base.connection.select_value(query)
    end

    def raise_unless_postgres
      raise "This functionality is supported only by PostgreSQL" unless self.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    end

    def drop_trigger_and_fun_sql(trigger_name, from_table, fun_name)
      %Q{
      DROP TRIGGER #{trigger_name} ON #{from_table};
      DROP FUNCTION #{fun_name}();
      }
    end

  end
end
