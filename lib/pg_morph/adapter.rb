module PgMorph
  module Adapter

    def add_polymorphic_foreign_key(from_table, to_table, options = {})
      raise_unless_postgres

      column_name = options[:column]
      raise "Column not specified" unless column_name

      # crete table with foreign key inheriting from original one
      sql = create_child_table_sql(from_table, to_table, column_name)

      # create trigger to send data to propper partition table
      sql << create_trigger_fun_sql(from_table, to_table, column_name)

      # create trigger before insert
      sql << create_before_insert_trigger_sql(from_table, to_table, column_name)

      execute(sql)
    end

    def remove_polymorphic_foreign_key(from_table, to_table, options = {})
      raise_unless_postgres

      column_name = options[:column]

      sql = remove_before_insert_trigger_sql(from_table, to_table, column_name)

      sql << remove_partition_table(from_table, to_table)

      execute(sql)
    end

    def create_child_table_sql(from_table, to_table, column_name)
      type = to_table.to_s.singularize.camelize
      column_name_type = "#{column_name}_type"
      column_name_id = "#{column_name}_id"
      child_table = "#{from_table}_#{to_table}"

      %Q{
      CREATE TABLE #{child_table} (
        CHECK (#{column_name_type} = '#{type}'),
        PRIMARY KEY (id),
        FOREIGN KEY (#{column_name_id}) REFERENCES #{to_table}(id)
      ) INHERITS (#{from_table});
      }
    end

    def create_trigger_fun_sql(from_table, to_table, column_name)
      fun_name = "#{from_table}_#{column_name}_fun"

      before_insert_trigger_content(fun_name, column_name) do
        create_trigger_body(from_table, to_table, column_name).strip
      end
    end

    def create_trigger_body(from_table, to_table, column_name)
      fun_name = "#{from_table}_#{column_name}_fun"

      prosrc = get_function(fun_name)

      if prosrc
        scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
        %Q{
          #{scan.map { |m| m[0] }.join.strip}
          ELSIF (NEW.#{column_name}_type = '#{to_table.to_s.singularize.camelize}') THEN
            INSERT INTO #{from_table}_#{to_table} VALUES (NEW.*);
        }
      else
        %Q{
          IF (NEW.#{column_name}_type = '#{to_table.to_s.singularize.camelize}') THEN
            INSERT INTO #{from_table}_#{to_table} VALUES (NEW.*);
        }
      end
    end

    def create_before_insert_trigger_sql(from_table, to_table, column_name)
      fun_name = "#{from_table}_#{column_name}_fun"
      trigger_name = "#{from_table}_#{column_name}_insert_trigger"

      %Q{
      DROP TRIGGER IF EXISTS #{trigger_name} ON #{from_table};
      CREATE TRIGGER #{trigger_name}
        BEFORE INSERT ON #{from_table}
        FOR EACH ROW EXECUTE PROCEDURE #{fun_name}();
      }
    end

    def remove_partition_table(from_table, to_table)
      table_empty = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{from_table}_#{to_table}").to_i.zero?
      if table_empty
        %Q{ DROP TABLE #{from_table}_#{to_table} }
      else
        raise PG::Error.new("Partition table #{from_table}_#{to_table} contains data.\nRemove them before if you want to drop that table.\n")
      end
    end

    def remove_before_insert_trigger_sql(from_table, to_table, column_name)
      trigger_name = "#{from_table}_#{column_name}_insert_trigger"
      fun_name = "#{from_table}_#{column_name}_fun"

      prosrc = get_function(fun_name)
      raise PG::Error.new("There is no such function #{fun_name}()\n") unless prosrc

      scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
      cleared = scan.reject { |x| x[0].match("#{from_table}_#{to_table}") }

      if cleared.present?
        cleared[0][0].sub!('ELSIF', 'IF')
        before_insert_trigger_content(fun_name, column_name) do
          cleared.map { |m| m[0] }.join('').strip
        end
      else
        %Q{
        DROP TRIGGER #{trigger_name} ON #{from_table};
        DROP FUNCTION #{fun_name}();
        }
      end
    end

    def before_insert_trigger_content(fun_name, column_name, &block)
      %Q{
        CREATE OR REPLACE FUNCTION #{fun_name}() RETURNS TRIGGER AS $$
        BEGIN
          #{block.call}
          ELSE
            RAISE EXCEPTION 'Wrong "#{column_name}_type"="%" used. Create propper partition table and update #{fun_name} function', NEW.content_type;
          END IF;
        RETURN NULL;
        END; $$ LANGUAGE plpgsql;
      }
    end

    def raise_unless_postgres
      raise "This functionality is supported only by PostgreSQL" unless self.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    end

    def get_function(fun_name)
      ActiveRecord::Base.connection.select_value("SELECT prosrc FROM pg_proc WHERE proname = '#{fun_name}'")
    end
  end
end
