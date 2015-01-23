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

  describe '#can_rename_to_base_table?' do
    it 'returns true if base table does not exist' do
      @adapter.stub(:table_exists?).with(@comments_polymorphic.base_table)
        .and_return(false)

      expect(@comments_polymorphic.can_rename_to_base_table?)
        .to be_true
    end

    it 'returns false if there is compatible base table' do
      @adapter.add_polymorphic_foreign_key(:likes, :posts, column: :likeable)

      expect(@comments_polymorphic.can_rename_to_base_table?)
        .to be_false
    end

    it 'raises an exception if existing base table is not compatible table' do
      @adapter.create_table(@comments_polymorphic.base_table)
      expect { @comments_polymorphic.can_rename_to_base_table? }.
        to raise_error PgMorph::Exception
    end
  end

  describe '#create_trigger_body' do
    before do
      @adapter.stub(:raise_unless_postgres)
    end

    it 'raises error for updating trigger with duplicated partition' do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect { @comments_polymorphic.send(:create_trigger_body) }
        .to raise_error PG::Error
    end

    it 'updates trigger with new partition' do
      @adapter.add_polymorphic_foreign_key(:likes, :comments, column: :likeable)

      expect(@posts_polymorphic.send(:create_trigger_body).squeeze(' ')).to eq %Q{
        IF (NEW.likeable_type = 'Comment') THEN
          INSERT INTO likes_comments VALUES (NEW.*);
        ELSIF (NEW.likeable_type = 'Post') THEN
          INSERT INTO likes_posts VALUES (NEW.*);
        }.squeeze(' ')
    end
  end

  describe '#create_before_insert_trigger_sql' do
    it 'returns sql' do
      expect(@comments_polymorphic.create_before_insert_trigger_sql.squeeze(' ')).to eq %Q{
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

      expect(@comments_polymorphic.remove_partition_table.squeeze(' ')).to eq %Q{ DROP TABLE IF EXISTS likes_comments; }
    end
  end

end
