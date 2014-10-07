module PgMorph

  Polymorphic = Struct.new(:from_table, :to_table, :options) do
    def column_name
      options[:column]
    end

    def type
      to_table.to_s.singularize.camelize
    end

    def column_name_type
      "#{column_name}_type"
    end

    def column_name_id
      "#{column_name}_id"
    end

    def child_table
      "#{from_table}_#{to_table}"
    end

    def before_insert_fun_name
      "#{from_table}_#{column_name}_fun"
    end

    def before_insert_trigger_name
      "#{from_table}_#{column_name}_insert_trigger"
    end

    def after_insert_fun_name
      "delete_from_#{from_table}_master_fun"
    end

    def after_insert_trigger_name
      "#{from_table}_after_insert_trigger"
    end

    def create_child_table_sql
      %Q{
      CREATE TABLE #{child_table} (
        CHECK (#{column_name_type} = '#{type}'),
        PRIMARY KEY (id),
        FOREIGN KEY (#{column_name_id}) REFERENCES #{to_table}(id)
      ) INHERITS (#{from_table});
      }
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

    def before_insert_trigger_content( &block)
      create_trigger_fun(before_insert_fun_name) do
        %Q{#{block.call}
          ELSE
            RAISE EXCEPTION 'Wrong "#{column_name}_type"="%" used. Create proper partition table and update #{before_insert_fun_name} function', NEW.#{column_name}_type;
          END IF;}
      end
    end

    def create_before_insert_trigger_fun_sql
      before_insert_trigger_content do
        create_trigger_body.strip
      end
    end

    def create_trigger_body
      prosrc = get_function(before_insert_fun_name)

      if prosrc
        scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
        raise PG::Error.new("Condition for #{child_table} table already exists in trigger function") if scan[0][0].match child_table
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

    def create_before_insert_trigger_sql
      fun_name = before_insert_fun_name
      trigger_name = before_insert_trigger_name

      create_trigger_sql(from_table, trigger_name, fun_name, 'BEFORE INSERT')
    end

    def create_after_insert_trigger_sql
      fun_name = after_insert_fun_name
      trigger_name = after_insert_trigger_name

      create_trigger_sql(from_table, trigger_name, fun_name, 'AFTER INSERT')
    end

    def create_trigger_sql(from_table, trigger_name, fun_name, when_to_call)
      %Q{
      DROP TRIGGER IF EXISTS #{trigger_name} ON #{from_table};
      CREATE TRIGGER #{trigger_name}
        #{when_to_call} ON #{from_table}
        FOR EACH ROW EXECUTE PROCEDURE #{fun_name}();
      }
    end

    def create_after_insert_trigger_fun_sql
      fun_name = after_insert_fun_name
      create_trigger_fun(fun_name) do
        %Q{DELETE FROM ONLY #{from_table} WHERE id = NEW.id;}
      end
    end

    def remove_before_insert_trigger_sql
      trigger_name = before_insert_trigger_name
      fun_name = before_insert_fun_name

      prosrc = get_function(fun_name)
      raise PG::Error.new("There is no such function #{fun_name}()\n") unless prosrc

      scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
      cleared = scan.reject { |x| x[0].match("#{child_table}") }

      if cleared.present?
        cleared[0][0].sub!('ELSIF', 'IF')
        before_insert_trigger_content do
          cleared.map { |m| m[0] }.join('').strip
        end
      else
        drop_trigger_and_fun_sql(trigger_name, from_table, fun_name)
      end
    end

    def drop_trigger_and_fun_sql(trigger_name, from_table, fun_name)
      %Q{
      DROP TRIGGER #{trigger_name} ON #{from_table};
      DROP FUNCTION #{fun_name}();
      }
    end

    def remove_partition_table
      table_empty = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{from_table}_#{to_table}").to_i.zero?
      if table_empty
        %Q{ DROP TABLE IF EXISTS #{child_table}; }
      else
        raise PG::Error.new("Partition table #{child_table} contains data.\nRemove them before if you want to drop that table.\n")
      end
    end

    def remove_after_insert_trigger_sql
      prosrc = get_function(before_insert_fun_name)
      scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
      cleared = scan.reject { |x| x[0].match("#{child_table}") }

      return '' if cleared.present?
      fun_name = after_insert_fun_name
      trigger_name = after_insert_trigger_name

      drop_trigger_and_fun_sql(trigger_name, from_table, fun_name)
    end

    def get_function(fun_name)
      run("SELECT prosrc FROM pg_proc WHERE proname = '#{fun_name}'")
    end

    def run(query)
      ActiveRecord::Base.connection.select_value(query)
    end
  end

end
