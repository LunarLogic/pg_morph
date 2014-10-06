module PgMorph

  module Adapter

    def add_polymorphic_foreign_key(from_table, to_table, options = {})
      raise_unless_postgres

      polymorphic = PgMorph::Polymorphic.new(from_table, to_table, options)

      column_name = options[:column]
      raise "Column not specified" unless column_name

      # crete table with foreign key inheriting from original one
      sql = create_child_table_sql(polymorphic)

      # create before insert function to send data to propper partition table
      sql << create_before_insert_trigger_fun_sql(from_table, to_table, column_name)

      # create trigger before insert
      sql << create_before_insert_trigger_sql(from_table, to_table, column_name)

      # create after insert function to remove duplicates
      sql << create_after_insert_trigger_fun_sql(from_table)

      # create trigger after insert
      sql << create_after_insert_trigger_sql(from_table)

      execute(sql)
    end

    def remove_polymorphic_foreign_key(from_table, to_table, options = {})
      raise_unless_postgres

      column_name = options[:column]

      sql = remove_before_insert_trigger_sql(from_table, to_table, column_name)

      sql << remove_partition_table(from_table, to_table)

      sql << remove_after_insert_trigger_sql(from_table, to_table, column_name)

      execute(sql)
    end

    def create_child_table_sql(polymorphic)
      %Q{
      CREATE TABLE #{polymorphic.child_table} (
        CHECK (#{polymorphic.column_name_type} = '#{polymorphic.type}'),
        PRIMARY KEY (id),
        FOREIGN KEY (#{polymorphic.column_name_id}) REFERENCES #{polymorphic.to_table}(id)
      ) INHERITS (#{polymorphic.from_table});
      }
    end

    def create_before_insert_trigger_fun_sql(from_table, to_table, column_name)
      fun_name = "#{from_table}_#{column_name}_fun"

      before_insert_trigger_content(fun_name, column_name) do
        create_trigger_body(from_table, to_table, column_name).strip
      end
    end

    def create_after_insert_trigger_fun_sql(from_table)
      fun_name = "delete_from_#{from_table}_master_fun"
      create_trigger_fun(fun_name) do
        %Q{DELETE FROM ONLY #{from_table} WHERE id = NEW.id;}
      end
    end

    def create_trigger_fun(fun_name, &block)
      %Q{
        CREATE OR REPLACE FUNCTION #{fun_name}() RETURNS TRIGGER AS $$
        BEGIN
          #{block.call}
          RETURN NEW;
        END; $$ LANGUAGE plpgsql;
      }
    end

    def create_after_insert_trigger_sql(from_table)
      fun_name = "delete_from_#{from_table}_master_fun"
      trigger_name = "#{from_table}_after_insert_trigger"

      create_trigger_sql(from_table, trigger_name, fun_name, 'AFTER INSERT')
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

      create_trigger_sql(from_table, trigger_name, fun_name, 'BEFORE INSERT')
    end

    def create_trigger_sql(from_table, trigger_name, fun_name, when_to_call)
      %Q{
      DROP TRIGGER IF EXISTS #{trigger_name} ON #{from_table};
      CREATE TRIGGER #{trigger_name}
        #{when_to_call} ON #{from_table}
        FOR EACH ROW EXECUTE PROCEDURE #{fun_name}();
      }
    end

    def remove_partition_table(from_table, to_table)
      table_empty = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{from_table}_#{to_table}").to_i.zero?
      if table_empty
        %Q{ DROP TABLE IF EXISTS #{from_table}_#{to_table}; }
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
        drop_trigger_and_fun_sql(trigger_name, from_table, fun_name)
      end
    end

    def remove_after_insert_trigger_sql(from_table, to_table, column_name)
      before_insert_fun_name = "#{from_table}_#{column_name}_fun"

      prosrc = get_function(before_insert_fun_name)
      scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
      cleared = scan.reject { |x| x[0].match("#{from_table}_#{to_table}") }

      return '' if cleared.present?
      fun_name = "delete_from_#{from_table}_master_fun"
      trigger_name = "#{from_table}_after_insert_trigger"

      drop_trigger_and_fun_sql(trigger_name, from_table, fun_name)
    end

    def before_insert_trigger_content(fun_name, column_name, &block)
      create_trigger_fun(fun_name) do
        %Q{#{block.call}
          ELSE
            RAISE EXCEPTION 'Wrong "#{column_name}_type"="%" used. Create proper partition table and update #{fun_name} function', NEW.#{column_name}_type;
          END IF;}
      end
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
