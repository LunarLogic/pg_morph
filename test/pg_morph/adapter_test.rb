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
  end

  test 'add_polymorphic_foreign_key for non postgres adapter' do
    -> { @adapter.add_polymorphic_foreign_key :likes, :posts, column: :likeable }
      .must_raise PgMorph::Exception
  end

  test 'remove_polymorphic_foreign_key for non postgres adapter' do
    -> { @adapter.remove_polymorphic_foreign_key :likes, :posts, column: :likeable }
      .must_raise PgMorph::Exception
  end
end
