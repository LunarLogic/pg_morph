module PgMorph

  Polymorphic = Struct.new(:from_table, :to_table, :options) do
    def column_name
      options[:column]
    end

    def type
      to_table.to_s.singularize.camelize
    end

    def column_name_type
      "#{column_name}_type"
    end

    def column_name_id
      "#{column_name}_id"
    end

    def child_table
      "#{from_table}_#{to_table}"
    end
  end

end
