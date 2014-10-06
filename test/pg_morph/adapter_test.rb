require_relative '../test_helper'

class PgMorph::AdapterTest < PgMorph::UnitTest

  class FakeAdapter
    include PgMorph::Adapter

    def execute(sql, name = nil)
      sql_statements << sql
      sql
    end

    def sql_statements
      @sql_statements || []
    end
  end

  setup do
    @adapter = FakeAdapter.new
    @connection = ActiveRecord::Base.connection
    @polymorphic = PgMorph::Polymorphic.new(:master_table, :child_table, column: :column)
  end

  test 'create_child_table_sql' do
    assert_equal(%Q{
      CREATE TABLE master_table_child_table (
        CHECK (column_type = 'ChildTable'),
        PRIMARY KEY (id),
          FOREIGN KEY (column_id) REFERENCES child_table(id)
      ) INHERITS (master_table);
      }.squeeze(' '),
      @adapter.create_child_table_sql(@polymorphic).squeeze(' ')
    )
  end

  test 'create_before_insert_trigger_fun_sql' do
    @adapter.expects(:before_insert_trigger_content)

    @adapter.create_before_insert_trigger_fun_sql(@polymorphic)
  end

  test 'create_after_insert_trigger_fun_sql' do
    assert_equal(%Q{
      CREATE OR REPLACE FUNCTION delete_from_master_table_master_fun() RETURNS TRIGGER AS $$
      BEGIN
        DELETE FROM ONLY master_table WHERE id = NEW.id;
        RETURN NEW;
      END; $$ LANGUAGE plpgsql;
      }.squeeze(' '),
      @adapter.create_after_insert_trigger_fun_sql(:master_table).squeeze(' ')
    )
  end

  test 'create_after_insert_trigger_sql' do
    assert_equal(%Q{
      DROP TRIGGER IF EXISTS master_table_after_insert_trigger ON master_table;
      CREATE TRIGGER master_table_after_insert_trigger
        AFTER INSERT ON master_table
        FOR EACH ROW EXECUTE PROCEDURE delete_from_master_table_master_fun();
      }.squeeze(' '),
      @adapter.create_after_insert_trigger_sql(:master_table).squeeze(' ')
    )
  end

  test 'create_trigger_body for new trigger' do
    assert_equal(%Q{
      IF (NEW.column_type = 'ChildTable') THEN
        INSERT INTO master_table_child_table VALUES (NEW.*);
      }.squeeze(' '),
      @adapter.create_trigger_body(@polymorphic).squeeze(' ')
    )
  end

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

  test 'remove_before_insert_trigger_sql if no function' do
    lambda { @adapter.remove_before_insert_trigger_sql(:master_table, :child_table, :column) }
      .must_raise PG::Error
  end

  test 'remove_before_insert_trigger_sql for single child table' do
    @adapter.stubs(:get_function).with('master_table_column_fun').returns('')

    assert_equal(%Q{
      DROP TRIGGER master_table_column_insert_trigger ON master_table;
      DROP FUNCTION master_table_column_fun();
      }.squeeze(' '),
      @adapter.remove_before_insert_trigger_sql(:master_table, :child_table, :column).squeeze(' ')
    )
  end

  test 'remove_before_insert_trigger_sql for multiple child tables' do
    @adapter.stubs(:get_function).with('master_table_column_fun')
      .returns(%Q{})

    assert_equal(%Q{
      DROP TRIGGER master_table_column_insert_trigger ON master_table;
      DROP FUNCTION master_table_column_fun();
      }.squeeze(' '),
      @adapter.remove_before_insert_trigger_sql(:master_table, :child_table, :column).squeeze(' ')
    )

  end

  test 'before_insert_trigger_content' do
    assert_equal(%Q{
      CREATE OR REPLACE FUNCTION function_name() RETURNS TRIGGER AS $$
        BEGIN
          my block
          ELSE
            RAISE EXCEPTION 'Wrong \"column_type\"=\"%\" used. Create proper partition table and update function_name function', NEW.column_type;
          END IF;
        RETURN NEW;
        END; $$ LANGUAGE plpgsql;
      }.squeeze(' '),
      @adapter.before_insert_trigger_content(:function_name, :column) { 'my block' }.squeeze(' ')
    )
  end

end
