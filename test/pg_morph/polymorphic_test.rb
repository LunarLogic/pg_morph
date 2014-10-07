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

  test '#after_insert_fun_name' do
    assert_equal 'delete_from_foos_master_fun', @polymorphic.after_insert_fun_name
  end

  test '#after_insert_trigger_name' do
    assert_equal 'foos_after_insert_trigger', @polymorphic.after_insert_trigger_name
  end

  test '#create_child_table_sql' do
    assert_equal(%Q{
      CREATE TABLE foos_bars (
        CHECK (baz_type = 'Bar'),
        PRIMARY KEY (id),
          FOREIGN KEY (baz_id) REFERENCES bars(id)
      ) INHERITS (foos);
      }.squeeze(' '),
      @polymorphic.create_child_table_sql.squeeze(' ')
    )
  end

  test 'create_before_insert_trigger_fun_sql' do
    @polymorphic.expects(:before_insert_trigger_content)

    @polymorphic.create_before_insert_trigger_fun_sql
  end

  test 'create_trigger_body for new trigger' do
    assert_equal(%Q{
      IF (NEW.baz_type = 'Bar') THEN
        INSERT INTO foos_bars VALUES (NEW.*);
      }.squeeze(' '),
      @polymorphic.create_trigger_body.squeeze(' ')
    )
  end

  test 'before_insert_trigger_content' do
    assert_equal(%Q{
      CREATE OR REPLACE FUNCTION foos_baz_fun() RETURNS TRIGGER AS $$
        BEGIN
          my block
          ELSE
            RAISE EXCEPTION 'Wrong \"baz_type\"=\"%\" used. Create proper partition table and update foos_baz_fun function', NEW.baz_type;
          END IF;
        RETURN NEW;
        END; $$ LANGUAGE plpgsql;
      }.squeeze(' '),
      @polymorphic.before_insert_trigger_content { 'my block' }.squeeze(' ')
    )
  end

  test 'create_after_insert_trigger_fun_sql' do
    assert_equal(%Q{
      CREATE OR REPLACE FUNCTION delete_from_foos_master_fun() RETURNS TRIGGER AS $$
      BEGIN
        DELETE FROM ONLY foos WHERE id = NEW.id;
        RETURN NEW;
      END; $$ LANGUAGE plpgsql;
      }.squeeze(' '),
      @polymorphic.create_after_insert_trigger_fun_sql.squeeze(' ')
    )
  end

  test 'create_after_insert_trigger_sql' do
    assert_equal(%Q{
      DROP TRIGGER IF EXISTS foos_after_insert_trigger ON foos;
      CREATE TRIGGER foos_after_insert_trigger
        AFTER INSERT ON foos
        FOR EACH ROW EXECUTE PROCEDURE delete_from_foos_master_fun();
      }.squeeze(' '),
      @polymorphic.create_after_insert_trigger_sql.squeeze(' ')
    )
  end
end
