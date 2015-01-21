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
    let(:comment) { Comment.create(content: 'comment') }
    let(:post) { Post.create(content: 'content') }

    before do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
      @comment_like = Like.create(likeable: comment)
    end

    context "creating records" do
      it "works with single partition" do
        expect(Like.count).to eq(1)
        expect(@comment_like.id).to eq(Like.last.id)
      end

      it "works with multiple partitions" do
        @adapter.add_polymorphic_foreign_key(:likes, :posts, column: :likeable)
        post_like = Like.create(likeable: post)

        expect(Like.count).to eq(2)
        expect(post_like.id).to eq(Like.last.id)
      end

      it "raises error for a missing partition" do
        -> {  Like.create(likeable: post) }
          .should raise_error ActiveRecord::StatementInvalid
      end

      it "works if no partitions" do
        @comment_like.destroy
        expect(Like.count).to eq(0)
        @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)
        like = Like.create(likeable: post)

        expect(Like.count).to eq(1)
        expect(like.id).to eq(Like.last.id)
      end
    end

    context "updating records" do
      let(:another_comment) { Comment.create(content: 'comment') }

      before do
        @adapter.add_polymorphic_foreign_key(:likes, :posts, column: :likeable)
      end

      it 'works within one partition' do
        expect(@comment_like.likeable).to eq(comment)

        @comment_like.likeable = another_comment
        @comment_like.save

        @comment_like.reload
        expect(@comment_like.likeable).to eq(another_comment)
      end

      it 'does not allow to change associated type' do
        expect(@comment_like.likeable).to eq(comment)

        @comment_like.likeable = post
        expect { @comment_like.save }.to raise_error ActiveRecord::StatementInvalid
      end
    end
  end

end
