require 'spec_helper'

describe PgMorph::Adapter do
  class FakeAdapter
    include PgMorph::Adapter
  end

  before do
    @adapter = FakeAdapter.new
    @connection = ActiveRecord::Base.connection
  end

  it 'add_polymorphic_foreign_key for non postgres adapter' do
    expect { @adapter.add_polymorphic_foreign_key :likes, :posts, column: :likeable }
      .to raise_error PgMorph::Exception
  end

  it 'remove_polymorphic_foreign_key for non postgres adapter' do
    expect { @adapter.remove_polymorphic_foreign_key :likes, :posts, column: :likeable }
      .to raise_error PgMorph::Exception
  end
end
