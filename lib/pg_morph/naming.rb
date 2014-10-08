module PgMorph
  module Naming

    def type
      child_table.to_s.singularize.camelize
    end

    def column_name_type
      "#{column_name}_type"
    end

    def column_name_id
      "#{column_name}_id"
    end

    def proxy_table
      "#{parent_table}_#{child_table}"
    end

    def before_insert_fun_name
      "#{parent_table}_#{column_name}_fun"
    end

    def before_insert_trigger_name
      "#{parent_table}_#{column_name}_insert_trigger"
    end

    def after_insert_fun_name
      "delete_from_#{parent_table}_master_fun"
    end

    def after_insert_trigger_name
      "#{parent_table}_after_insert_trigger"
    end

  end
end
