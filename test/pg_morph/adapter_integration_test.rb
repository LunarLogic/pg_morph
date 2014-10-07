require_relative '../test_helper'

class PgMorph::AdapterIntegrationTest < PgMorph::UnitTest
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

  teardown do
    begin
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
    rescue
    end
  end

  test 'add_polymorphic_foreign_key' do
    -> { @adapter.run('SELECT id FROM likes_comments') }
      .must_raise ActiveRecord::StatementInvalid

    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    assert_equal(nil, @adapter.run('SELECT id FROM likes_comments'))
  end

  test 'remove_polymorphic_foreign_key' do
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
    assert_equal(nil, @adapter.run('SELECT id FROM likes_comments'))

    @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    -> { @adapter.run('SELECT id FROM likes_comments') }
      .must_raise ActiveRecord::StatementInvalid
  end

  test 'assertions to a partition' do
    # new record inserted correctly
    @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
    comment = Comment.create(content: 'comment')
    like = Like.create(likeable: comment)

    assert_equal(1, Like.count)
    assert_equal(Like.last.id, like.id)

    # new record with more partition tables inserted correctly
    @adapter.add_polymorphic_foreign_key(:likes, :posts, column: :likeable)
    post = Post.create(content: 'content')
    like2 = Like.create(likeable: post)

    assert_equal(2, Like.count)
    assert_equal(Like.last.id, like2.id)

    # after removing partition row not inserted
    like.destroy
    assert_equal(1, Like.count)
    @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

    -> {  Like.create(likeable: comment) }
      .must_raise ActiveRecord::StatementInvalid

    # if no partitions row inserted correctly
    like2.destroy
    assert_equal(0, Like.count)
    @adapter.remove_polymorphic_foreign_key(:likes, :posts, column: :likeable)
    like4 = Like.create(likeable: post)

    assert_equal(1, Like.count)
    assert_equal(Like.last.id, like4.id)
  end

end
