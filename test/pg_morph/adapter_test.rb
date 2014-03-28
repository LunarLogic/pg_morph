require_relative '../test_helper'

class PgMorph::AdapterTest < PgMorph::UnitTest
  class FakeAdapter
    include PgMorph::Adapter
  end

  setup do
    @adapter = FakeAdapter.new
  end

  test 'add_polymorphic_foreign_key'
  test 'remove_polymorphic_foreign_key'

  test 'create_child_table_sql' do
    assert_equal(%Q{
      CREATE TABLE master_table_child_table (
        CHECK (column_type = 'ChildTable'),
        PRIMARY KEY (id),
          FOREIGN KEY (column_id) REFERENCES child_table(id)
      ) INHERITS (master_table);
      }.squeeze(' '),
      @adapter.create_child_table_sql(:master_table, :child_table, :column).squeeze(' ')
    )
  end

  test 'create_trigger_fun_sql'

  test 'create_trigger_body for new trigger' do
    assert_equal(%Q{
      IF (NEW.column_type = 'ChildTable') THEN
        INSERT INTO master_table_child_table VALUES (NEW.*);
      }.squeeze(' '),
      @adapter.create_trigger_body(:master_table, :child_table, :column).squeeze(' ')
    )
  end

  test 'create_trigger_body for existing trigger'

  test 'create_before_insert_trigger_sql' do
    assert_equal(%Q{
      DROP TRIGGER IF EXISTS master_table_column_insert_trigger ON master_table;
      CREATE TRIGGER master_table_column_insert_trigger
        BEFORE INSERT ON master_table
        FOR EACH ROW EXECUTE PROCEDURE master_table_column_fun();
      },
      @adapter.create_before_insert_trigger_sql(:master_table, :to_table, :column)
    )
  end

  test 'remove_partition_table'
  test 'remove_before_insert_trigger_sql'
  test 'before_insert_trigger_content' do
    assert_equal(%Q{
      CREATE OR REPLACE FUNCTION function_name() RETURNS TRIGGER AS $$
        BEGIN
          my block
          ELSE
            RAISE EXCEPTION 'Wrong \"column_type\"=\"%\" used. Create propper partition table and update function_name function', NEW.content_type;
          END IF;
        RETURN NEW;
        END; $$ LANGUAGE plpgsql;
      }.squeeze(' '),
      @adapter.before_insert_trigger_content(:function_name, :column) { 'my block' }.squeeze(' ')
    )
  end

end
