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

  describe '#rename_base_table_sql' do
    it 'returns proper sql if there is no base table yet' do
      expect(@polymorphic.rename_base_table_sql.squeeze(' ')).to eq %Q{
        ALTER TABLE foos RENAME TO foos_base;
      }.squeeze(' ')
    end

    it 'returns empty string if base table exists' do
      expect(ActiveRecord::Base.connection).to receive(:table_exists?).and_return(true)
      expect(@polymorphic.rename_base_table_sql.squeeze(' ')).to eq ''
    end
  end

  describe '#create_base_table_view_sql' do
    it 'returns proper sql' do
      expect(@polymorphic.create_base_table_view_sql).to eq %Q{
        CREATE OR REPLACE VIEW foos AS SELECT * FROM foos_base;
      }
    end
  end

  describe '#create_proxy_table_sql' do
    it 'generates proper sql' do
      expect(@polymorphic.create_proxy_table_sql.squeeze(' ')).to eq %Q{
      CREATE TABLE foos_bars (
        CHECK (baz_type = 'Bar'),
        PRIMARY KEY (id),
          FOREIGN KEY (baz_id) REFERENCES bars(id)
      ) INHERITS (foos_base);
      }.squeeze(' ')
    end
  end

  describe '#create_before_insert_trigger_fun_sql' do
    it 'generates proper sql' do
      expect(@polymorphic).to receive(:before_insert_trigger_content)

      @polymorphic.create_before_insert_trigger_fun_sql
    end
  end

  describe '#create_trigger_body' do
    it 'returns proper sql for new trigger' do
      expect(@polymorphic.send(:create_trigger_body).squeeze(' ')).to eq %Q{
      IF (NEW.baz_type = 'Bar') THEN
        INSERT INTO foos_bars VALUES (NEW.*);
      }.squeeze(' ')
    end
  end

  describe '#before_insert_trigger_content' do
    it 'generate proper sql' do
      expect(@polymorphic.send(:before_insert_trigger_content) { 'my block' }.squeeze(' ')).to eq %Q{
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

  describe '#remove_before_insert_trigger_sql' do
    it 'raise error if no function' do
      expect { @polymorphic.remove_before_insert_trigger_sql }
        .to raise_error PG::Error
    end

    it 'returns proper sql for single child table' do
      @polymorphic.stub(:get_function).with('foos_baz_fun').and_return('')

      expect(@polymorphic.remove_before_insert_trigger_sql.squeeze(' ')).to eq %Q{
        DROP TRIGGER foos_baz_insert_trigger ON foos;
        DROP FUNCTION foos_baz_fun();
        }.squeeze(' ')
    end
  end
end
