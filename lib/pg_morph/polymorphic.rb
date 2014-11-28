require 'pry'
module PgMorph

  class Polymorphic
    BASE_TABLE_SUFIX = :base

    include PgMorph::Naming
    attr_reader :parent_table, :child_table, :column_name, :base_table

    def initialize(parent_table, child_table, options)
      @parent_table = parent_table
      @child_table = child_table
      @column_name = options[:column]
      @base_table = options[:base_table] || :"#{parent_table}_#{BASE_TABLE_SUFIX}"

      raise PgMorph::Exception.new("Column not specified") unless @column_name
    end

    def rename_base_table_sql
      return '' if ActiveRecord::Base.connection.table_exists? base_table
      %Q{
        ALTER TABLE #{parent_table} RENAME TO #{base_table};
      }
    end

    def create_base_table_view_sql
      %Q{
        CREATE OR REPLACE VIEW #{parent_table} AS SELECT * FROM #{base_table};
      }
    end

    def create_proxy_table_sql
      %Q{
      CREATE TABLE #{proxy_table} (
        CHECK (#{column_name_type} = '#{type}'),
        PRIMARY KEY (id),
        FOREIGN KEY (#{column_name_id}) REFERENCES #{child_table}(id)
      ) INHERITS (#{base_table});
      }
    end

    def create_before_insert_trigger_fun_sql
      before_insert_trigger_content do
        %Q{
        IF NEW.id IS NULL THEN
          NEW.id := nextval('#{parent_table}_id_seq');
        END IF;
        #{create_trigger_body.strip}
        }
      end
    end

    def create_before_insert_trigger_sql
      fun_name = before_insert_fun_name
      trigger_name = before_insert_trigger_name

      create_trigger_sql(parent_table, trigger_name, fun_name, 'INSTEAD OF INSERT')
    end

    def remove_before_insert_trigger_sql
      trigger_name = before_insert_trigger_name
      fun_name = before_insert_fun_name

      prosrc = get_function(fun_name)
      raise PG::Error.new("There is no such function #{fun_name}()\n") unless prosrc

      scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
      cleared = scan.reject { |x| x[0].match("#{proxy_table}") }

      if cleared.present?
        cleared[0][0].sub!('ELSIF', 'IF')
        before_insert_trigger_content do
          cleared.map { |m| m[0] }.join('').strip
        end
      else
        drop_trigger_and_fun_sql(trigger_name, parent_table, fun_name)
      end
    end

    def remove_partition_table
      table_empty = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{parent_table}_#{child_table}").to_i.zero?
      if table_empty
        %Q{ DROP TABLE IF EXISTS #{proxy_table}; }
      else
        raise PG::Error.new("Partition table #{proxy_table} contains data.\nRemove them before if you want to drop that table.\n")
      end
    end

    private

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

    def create_trigger_body
      prosrc = get_function(before_insert_fun_name)

      if prosrc
        scan =  prosrc.scan(/(( +(ELS)?IF.+\n)(\s+INSERT INTO.+;\n))/)
        raise PG::Error.new("Condition for #{proxy_table} table already exists in trigger function") if scan[0][0].match proxy_table
        %Q{
          #{scan.map { |m| m[0] }.join.strip}
          ELSIF (NEW.#{column_name}_type = '#{child_table.to_s.singularize.camelize}') THEN
            INSERT INTO #{parent_table}_#{child_table} VALUES (NEW.*);
        }
      else
        %Q{
          IF (NEW.#{column_name}_type = '#{child_table.to_s.singularize.camelize}') THEN
            INSERT INTO #{parent_table}_#{child_table} VALUES (NEW.*);
        }
      end
    end

    def create_trigger_sql(parent_table, trigger_name, fun_name, when_to_call)
      %Q{
      DROP TRIGGER IF EXISTS #{trigger_name} ON #{parent_table};
      CREATE TRIGGER #{trigger_name}
        #{when_to_call} ON #{parent_table}
        FOR EACH ROW EXECUTE PROCEDURE #{fun_name}();
      }
    end

    def drop_trigger_and_fun_sql(trigger_name, parent_table, fun_name)
      %Q{
      DROP TRIGGER #{trigger_name} ON #{parent_table};
      DROP FUNCTION #{fun_name}();
      }
    end

    def get_function(fun_name)
      run("SELECT prosrc FROM pg_proc WHERE proname = '#{fun_name}'")
    end

    def run(query)
      ActiveRecord::Base.connection.select_value(query)
    end
  end

end
