require_relative '../test_helper'

class PgMorph::PolymorphicTest < PgMorph::UnitTest
  setup do
    @polymorphic = PgMorph::Polymorphic.new(:foos, :bars, column: :baz)
  end

  test '#column_name' do
    assert_equal :baz, @polymorphic.column_name
  end

  test '#type' do
    assert_equal 'Bar', @polymorphic.type
  end

  test '#column_name_type' do
    assert_equal 'baz_type', @polymorphic.column_name_type
  end

  test '#column_name_id' do
    assert_equal 'baz_id', @polymorphic.column_name_id
  end

  test '#child_table' do
    assert_equal 'foos_bars', @polymorphic.child_table
  end

  test '#before_insert_fun_name' do
    assert_equal 'foos_baz_fun', @polymorphic.before_insert_fun_name
  end

  test '#before_insert_trigger_name' do
    assert_equal 'foos_baz_insert_trigger', @polymorphic.before_insert_trigger_name
  end
end
