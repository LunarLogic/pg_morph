require_relative '../test_helper'

class PgMorph::AdapterIntegrationTest < PgMorph::UnitTest
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    include PgMorph::Adapter
  end

  setup do
    @adapter = ActiveRecord::Base.connection
    begin
      @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)
    rescue
    end
  end

  teardown do
    begin
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
    rescue
    end
  end

  test 'create_trigger_body for updating trigger with new partition' do
    @adapter.stubs(:raise_unless_postgres)
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    assert_equal(%Q{
      IF (NEW.likeable_type = 'Comment') THEN
        INSERT INTO likes_comments VALUES (NEW.*);
      ELSIF (NEW.likeable_type = 'Post') THEN
        INSERT INTO likes_posts VALUES (NEW.*);
      }.squeeze(' '),
      @adapter.create_trigger_body(:likes, :posts, :likeable).squeeze(' '))
  end

  test 'add_polymorphic_foreign_key' do
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
  end

  test 'remove_partition_table' do
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    assert_equal(%Q{ DROP TABLE IF EXISTS likes_comments },
      @adapter.remove_partition_table(:likes, :comments))
  end


  test 'remove_polymorphic_foreign_key' do
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
  end

end
