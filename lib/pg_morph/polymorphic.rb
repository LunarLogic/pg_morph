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

    def before_insert_fun_name
      "#{from_table}_#{column_name}_fun"
    end

    def before_insert_trigger_name
      "#{from_table}_#{column_name}_insert_trigger"
    end
  end

end
