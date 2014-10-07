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

end
