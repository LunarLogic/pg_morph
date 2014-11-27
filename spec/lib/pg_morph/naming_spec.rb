require 'spec_helper'

describe PgMorph::Naming do

  Fake = Struct.new(:parent_table, :child_table, :column_name) do
    include PgMorph::Naming
  end

  before do
    @fake = Fake.new(:foos, :bars, :baz)
  end

  it { expect(@fake.type).to eq('Bar') }

  it { expect(@fake.column_name_type).to eq('baz_type') }

  it { expect(@fake.column_name_id).to eq('baz_id') }

  it { expect(@fake.proxy_table).to eq('foos_bars') }

  it { expect(@fake.before_insert_fun_name).to eq('foos_baz_fun') }

  it { expect(@fake.before_insert_trigger_name).to eq('foos_baz_insert_trigger') }

  it { expect(@fake.after_insert_fun_name).to eq('delete_from_foos_master_fun') }

  it { expect(@fake.after_insert_trigger_name).to eq('foos_after_insert_trigger') }

end
