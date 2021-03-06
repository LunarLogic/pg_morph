require 'spec_helper'

describe PgMorph::Adapter do
  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
    include PgMorph::Adapter

    def pg_views(name = nil)
      query(%Q{
        SELECT viewname
        FROM pg_views
        WHERE schemaname = ANY (current_schemas(false))
      }, 'SCHEMA').map { |row| row[0] }
    end

    def run(query)
      ActiveRecord::Base.connection.select_value(query)
    end
  end

  let(:comment) { Comment.create(content: 'comment') }

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
    it 'renames base table' do
      expect(@adapter.tables).to include "likes"
      expect(@adapter.tables).not_to include "likes_base"

      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.tables).not_to include "likes"
      expect(@adapter.tables).to include "likes_base"
    end

    it 'creates base table view' do
      expect(@adapter.pg_views).to be_empty
      expect(@adapter.tables).to include "likes"

      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.pg_views).to include "likes"
      expect(@adapter.tables).not_to include "likes"
    end

    it 'creates proxy table' do
      expect(@adapter.tables).not_to include "likes_comments"

      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.tables).to include "likes_comments"
    end

    it 'creates before insert trigger fun' do
      fun_name = @comments_polymorphic.before_insert_fun_name
      expect(@adapter.run("select proname from pg_proc where proname = '#{fun_name}'")).
        to be nil

      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.run("select proname from pg_proc where proname = '#{fun_name}'")).
        to eq fun_name
    end

    it 'creates before insert trigger' do
      trigger_name = @comments_polymorphic.before_insert_trigger_name
      expect(@adapter.query("SELECT * FROM pg_trigger WHERE tgname = '#{trigger_name}'")).
        to be_empty

      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.query("SELECT count(*) FROM pg_trigger WHERE tgname = '#{trigger_name}'")).
        to eq [["1"]]
    end
  end

  describe '#remove_polymorphic_foreign_key' do
    before do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
    end

    it 'removes before insert trigger' do
      fun_name = @comments_polymorphic.before_insert_fun_name
      expect(@adapter.run("select proname from pg_proc where proname = '#{fun_name}'")).
        to eq fun_name

      @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.run("select proname from pg_proc where proname = '#{fun_name}'")).
        to be nil
    end

    it 'removes before insert trigger fun' do
      trigger_name = @comments_polymorphic.before_insert_trigger_name
      expect(@adapter.query("SELECT count(*) FROM pg_trigger WHERE tgname = '#{trigger_name}'")).
        to eq [["1"]]

      @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.query("SELECT * FROM pg_trigger WHERE tgname = '#{trigger_name}'")).
        to be_empty
    end

    it 'removes proxy table' do
      expect(@adapter.tables).to include "likes_comments"

      @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.tables).not_to include "likes_comments"
    end

    it 'prevents from removing proxy with data' do
      Like.create(likeable: comment)

      -> { @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable) }
        .should raise_error PG::Error
    end

    it 'removes table view if empty' do
      expect(@adapter.pg_views).to include "likes"
      expect(@adapter.tables).not_to include "likes"

      @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.pg_views).to be_empty
    end

    it 'renames base table to original name' do
      expect(@adapter.pg_views).to include "likes"
      expect(@adapter.tables).not_to include "likes"

      @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@adapter.tables).to include "likes"
    end

    context 'with more than one partitions' do
      before do
        @adapter.add_polymorphic_foreign_key(:likes, :posts, column: :likeable)
      end

      it 'does not rename base table to original name' do
        expect(@adapter.pg_views).to include "likes"
        expect(@adapter.tables).not_to include "likes"

        @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)

        expect(@adapter.tables).not_to include "likes"
        expect(@adapter.pg_views).to include "likes"
      end
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

    context "deleting records" do
      before do
        expect(@adapter.run("SELECT id from likes where id = #{@comment_like.id}"))
          .to eq @comment_like.id.to_s
        expect(@adapter.run("SELECT id from likes_comments where id = #{@comment_like.id}"))
          .to eq @comment_like.id.to_s
        @comment_like.destroy
      end

      it "works on a partition" do
        expect(@adapter.run("SELECT id from likes where id = #{@comment_like.id}")).to eq nil
        expect(@adapter.run("SELECT id from likes_comments where id = #{@comment_like.id}")).to eq nil
      end

      context "after removing paritions" do
        before do
          @adapter.remove_polymorphic_foreign_key(:likes, :comments, column: :likeable)
          @like = Like.create(likeable: comment)
        end

        it "works on a master table" do
          @like.destroy
          expect(@adapter.run("SELECT id from likes where id = #{@comment_like.id}")).to eq nil
        end
      end
    end
  end

end
