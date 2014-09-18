require_relative '../test_helper'

class PgMorph::AdapterIntegrationTest < PgMorph::UnitTest
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    include PgMorph::Adapter
  end

  setup do
    @adapter = ActiveRecord::Base.connection
    begin
      Like.destroy_all
      Comment.destroy_all
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
    -> { @adapter.run('SELECT id FROM likes_comments') }
      .must_raise ActiveRecord::StatementInvalid

    assert_send [@adapter, :create_child_table_sql, :likes, :comments, :likeable]
    assert_send [@adapter, :create_before_insert_trigger_fun_sql, :likes, :comments, :likeable]
    assert_send [@adapter, :create_before_insert_trigger_sql, :likes, :comments, :likeable]
    assert_send [@adapter, :create_after_insert_trigger_fun_sql, :likes]
    assert_send [@adapter, :create_after_insert_trigger_sql, :likes]

    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    assert_equal(nil, @adapter.run('SELECT id FROM likes_comments'))
  end

  test 'remove_partition_table' do
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    assert_equal(%Q{ DROP TABLE IF EXISTS likes_comments },
      @adapter.remove_partition_table(:likes, :comments))
  end

  test 'remove_polymorphic_foreign_key' do
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
    assert_equal(nil, @adapter.run('SELECT id FROM likes_comments'))

    assert_send [@adapter, :remove_before_insert_trigger_sql, :likes, :comments, :likeable]
    assert_send [@adapter, :remove_partition_table, :likes, :comments]

    @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    -> { @adapter.run('SELECT id FROM likes_comments') }
      .must_raise ActiveRecord::StatementInvalid
  end

  test 'assertions to a partition' do
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    comment = Comment.create(content: 'comment')
    like = Like.create(likeable: comment)

    assert_equal(Like.count, 1)
    assert_equal(like.id, Like.last.id)
  end

end
