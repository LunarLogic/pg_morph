require_relative '../test_helper'

class PgMorph::PolymorphicIntegrationTest < PgMorph::UnitTest
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    include PgMorph::Adapter

    def run(query)
      ActiveRecord::Base.connection.select_value(query)
    end
  end

  setup do
    @adapter = ActiveRecord::Base.connection
    @comments_polymorphic = PgMorph::Polymorphic.new(:likes, :comments, column: :likeable)
    @posts_polymorphic = PgMorph::Polymorphic.new(:likes, :posts, column: :likeable)
    begin
      Like.destroy_all
      Comment.destroy_all
      @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)
      @adapter.remove_polymorphic_foreign_key(:likes, :posts, column: :likeable)
    rescue
    end
  end

  test 'create_trigger_body for updating trigger with dulicated partition' do
    @adapter.stubs(:raise_unless_postgres)
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    -> { @comments_polymorphic.create_trigger_body }
      .must_raise RuntimeError
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
      @posts_polymorphic.create_trigger_body.squeeze(' '))
  end

  test 'create_before_insert_trigger_sql' do
    assert_equal(%Q{
      DROP TRIGGER IF EXISTS likes_likeable_insert_trigger ON likes;
      CREATE TRIGGER likes_likeable_insert_trigger
        BEFORE INSERT ON likes
        FOR EACH ROW EXECUTE PROCEDURE likes_likeable_fun();
      },
      @comments_polymorphic.create_before_insert_trigger_sql
    )
  end

end
