require 'spec_helper'

describe PgMorph::Polymorphic do
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

  describe '#create_trigger_body' do
    before do
      @adapter.stub(:raise_unless_postgres)
    end

    it 'raises error for updating trigger with duplicated partition' do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      -> { @comments_polymorphic.send(:create_trigger_body) }
        .should raise_error PG::Error
    end

    it 'updates trigger with new partition' do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      @posts_polymorphic.send(:create_trigger_body).squeeze(' ').should == %Q{
        IF (NEW.likeable_type = 'Comment') THEN
          INSERT INTO likes_comments VALUES (NEW.*);
        ELSIF (NEW.likeable_type = 'Post') THEN
          INSERT INTO likes_posts VALUES (NEW.*);
        }.squeeze(' ')
    end
  end

  describe '#create_before_insert_trigger_sql' do
    it 'returns sql' do
      @comments_polymorphic.create_before_insert_trigger_sql.squeeze(' ').should == %Q{
      DROP TRIGGER IF EXISTS likes_likeable_insert_trigger ON likes;
      CREATE TRIGGER likes_likeable_insert_trigger
        INSTEAD OF INSERT ON likes
        FOR EACH ROW EXECUTE PROCEDURE likes_likeable_fun();
      }.squeeze(' ')
    end
  end

  describe '#remove_partition_table' do
    it 'returns sql' do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      @comments_polymorphic.remove_partition_table.squeeze(' ').should == %Q{ DROP TABLE IF EXISTS likes_comments; }
    end
  end

  describe 'remove_after_insert_trigger_sql' do
    it 'returns sql' do
      pending "won't be used any more"
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      @comments_polymorphic.remove_after_insert_trigger_sql.squeeze(' ').should == %Q{
        DROP TRIGGER likes_after_insert_trigger ON likes;
        DROP FUNCTION delete_from_likes_master_fun();
        }.squeeze(' ')
    end

    it 'returns empty string if there are more partitions' do
      pending "won't be used any more"
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)
      @adapter.add_polymorphic_foreign_key(:likes, :posts, column: :likeable)

      @comments_polymorphic.remove_after_insert_trigger_sql.squeeze(' ').should == ''
    end
  end

end
