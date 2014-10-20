require 'spec_helper'

describe PgMorph::Polymorphic do
  before do
    @polymorphic = PgMorph::Polymorphic.new(:foos, :bars, column: :baz)
  end

  subject { @polymorphic }

  it { expect(@polymorphic.column_name).to eq(:baz) }

  it { expect(@polymorphic.parent_table).to eq(:foos) }

  it { expect(@polymorphic.child_table).to eq(:bars) }

  describe "#base_table" do
    it "sets default base table" do
      expect(@polymorphic.base_table).to eq(:foos_base)
    end

    it "sets base table with options" do
      polymorphic = PgMorph::Polymorphic.new(:foos, :bars, column: :baz, base_table: :base)
      expect(polymorphic.base_table).to eq(:base)
    end
  end

  describe '#create_proxy_table_sql' do
    it do
      @polymorphic.create_proxy_table_sql.squeeze(' ').should == %Q{
      CREATE TABLE foos_bars (
        CHECK (baz_type = 'Bar'),
        PRIMARY KEY (id),
          FOREIGN KEY (baz_id) REFERENCES bars(id)
      ) INHERITS (foos_base);
      }.squeeze(' ')
    end
  end

  describe '#create_before_insert_trigger_fun_sql' do
    it '' do
      @polymorphic.should_receive(:before_insert_trigger_content)

      @polymorphic.create_before_insert_trigger_fun_sql
    end
  end

  describe '#create_trigger_body' do
    it 'returns proper sql for new trigger' do
      @polymorphic.send(:create_trigger_body).squeeze(' ').should == %Q{
      IF (NEW.baz_type = 'Bar') THEN
        INSERT INTO foos_bars VALUES (NEW.*);
      }.squeeze(' ')
    end
  end

  describe '#before_insert_trigger_content' do
    it '' do
      @polymorphic.send(:before_insert_trigger_content) { 'my block' }.squeeze(' ').should == %Q{
      CREATE OR REPLACE FUNCTION foos_baz_fun() RETURNS TRIGGER AS $$
        BEGIN
          my block
          ELSE
            RAISE EXCEPTION 'Wrong \"baz_type\"=\"%\" used. Create proper partition table and update foos_baz_fun function', NEW.baz_type;
          END IF;
        RETURN NEW;
        END; $$ LANGUAGE plpgsql;
      }.squeeze(' ')
    end
  end

  describe '#create_after_insert_trigger_fun_sql' do
    it do
      @polymorphic.create_after_insert_trigger_fun_sql.squeeze(' ').should == %Q{
      CREATE OR REPLACE FUNCTION delete_from_foos_master_fun() RETURNS TRIGGER AS $$
      BEGIN
        DELETE FROM ONLY foos WHERE id = NEW.id;
        RETURN NEW;
      END; $$ LANGUAGE plpgsql;
      }.squeeze(' ')
    end
  end

  describe '#create_after_insert_trigger_sql' do
    it do
      @polymorphic.create_after_insert_trigger_sql.squeeze(' ').should == %Q{
      DROP TRIGGER IF EXISTS foos_after_insert_trigger ON foos;
      CREATE TRIGGER foos_after_insert_trigger
        AFTER INSERT ON foos
        FOR EACH ROW EXECUTE PROCEDURE delete_from_foos_master_fun();
      }.squeeze(' ')
    end
  end

  describe '#remove_before_insert_trigger_sql' do
    it 'raise error if no function' do
      -> { @polymorphic.remove_before_insert_trigger_sql }
        .should raise_error PG::Error
    end

    it 'returns proper sql for single child table' do
      @polymorphic.stub(:get_function).with('foos_baz_fun').and_return('')

      @polymorphic.remove_before_insert_trigger_sql.squeeze(' ').should == %Q{
        DROP TRIGGER foos_baz_insert_trigger ON foos;
        DROP FUNCTION foos_baz_fun();
        }.squeeze(' ')
    end
  end
end
