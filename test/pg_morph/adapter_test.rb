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

  test 'remove_before_insert_trigger_sql if no function' do
    lambda { @adapter.remove_before_insert_trigger_sql(@polymorphic) }
      .must_raise PG::Error
  end

  test 'remove_before_insert_trigger_sql for single child table' do
    @adapter.stubs(:get_function).with('master_table_column_fun').returns('')

    assert_equal(%Q{
      DROP TRIGGER master_table_column_insert_trigger ON master_table;
      DROP FUNCTION master_table_column_fun();
      }.squeeze(' '),
      @adapter.remove_before_insert_trigger_sql(@polymorphic).squeeze(' ')
    )
  end

  test 'remove_before_insert_trigger_sql for multiple child tables' do
    @adapter.stubs(:get_function).with('master_table_column_fun')
      .returns(%Q{})

    assert_equal(%Q{
      DROP TRIGGER master_table_column_insert_trigger ON master_table;
      DROP FUNCTION master_table_column_fun();
      }.squeeze(' '),
      @adapter.remove_before_insert_trigger_sql(@polymorphic).squeeze(' ')
    )

  end

end
