require_relative '../test_helper'

class PgMorph::NamingTest < PgMorph::UnitTest
  Fake = Struct.new(:parent_table, :child_table, :column_name) do
    include PgMorph::Naming
  end

  setup do
    @fake = Fake.new(:foos, :bars, :baz)
  end

  test '#type' do
    assert_equal 'Bar', @fake.type
  end

  test '#column_name_type' do
    assert_equal 'baz_type', @fake.column_name_type
  end

  test '#column_name_id' do
    assert_equal 'baz_id', @fake.column_name_id
  end

  test '#proxy_table' do
    assert_equal 'foos_bars', @fake.proxy_table
  end

  test '#before_insert_fun_name' do
    assert_equal 'foos_baz_fun', @fake.before_insert_fun_name
  end

  test '#before_insert_trigger_name' do
    assert_equal 'foos_baz_insert_trigger', @fake.before_insert_trigger_name
  end

  test '#after_insert_fun_name' do
    assert_equal 'delete_from_foos_master_fun', @fake.after_insert_fun_name
  end

  test '#after_insert_trigger_name' do
    assert_equal 'foos_after_insert_trigger', @fake.after_insert_trigger_name
  end

end
