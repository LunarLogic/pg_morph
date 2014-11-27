require 'spec_helper'

describe PgMorph::Adapter do
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    include PgMorph::Adapter

    def run(query)
      ActiveRecord::Base.connection.select_value(query)
    end
  end

  before do
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

  after do
    begin
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
    rescue
    end
  end

  describe '#add_polymorphic_foreign_key' do
    it 'creates proxy table' do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.run('SELECT id FROM likes_comments')).to be_nil
    end
  end

  describe '#remove_polymorphic_foreign_key' do
    it 'removes proxy table' do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
      expect(@adapter.run('SELECT id FROM likes_comments')).to be_nil

      @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      -> { @adapter.run('SELECT id FROM likes_comments') }
        .should raise_error ActiveRecord::StatementInvalid
    end
  end

  describe 'operations on a partition' do
    before do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
    end

    it 'creates records' do
      # new record inserted correctly
      comment = Comment.create(content: 'comment')
      like = Like.create(likeable: comment)

      expect(Like.count).to eq(1)
      expect(like.id).to eq(Like.last.id)

      # new record with more partition tables inserted correctly
      @adapter.add_polymorphic_foreign_key(:likes, :posts, column: :likeable)
      post = Post.create(content: 'content')
      like2 = Like.create(likeable: post)

      expect(Like.count).to eq(2)
      expect(like2.id).to eq(Like.last.id)

      #after removing partition row not inserted
      like.destroy
      expect(Like.count).to eq(1)
      @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      -> {  Like.create(likeable: comment) }
        .should raise_error ActiveRecord::StatementInvalid

      #if no partitions row inserted correctly
      like2.destroy
      expect(Like.count).to eq(0)
      @adapter.remove_polymorphic_foreign_key(:likes, :posts, column: :likeable)
      like4 = Like.create(likeable: post)

      expect(Like.count).to eq(1)
      expect(like4.id).to eq(Like.last.id)
    end

    it 'updates records' do
      comment = Comment.create(content: 'comment')
      comment2 = Comment.create(content: 'comment2')
      like = Like.create(likeable: comment)

      like.reload
      expect(like.likeable).to eq(comment)

      like.likeable = comment2
      like.save

      like.reload
      expect(like.likeable).to eq(comment2)
    end
  end

end
