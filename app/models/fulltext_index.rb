class FulltextIndex < ActiveRecord::Base
  belongs_to :searchable, polymorphic: true, required: true

  # valid weight keys. the default weights assigned are {1, 0.4, 0.2, 0.1}
  WEIGHTS = %w[A B C D].freeze

  # the postgresql indexing config to be used
  SEARCH_CONFIG = 'redmine_search'.freeze
  WORD_CONFIG = 'redmine_search_words'.freeze

  scope :search, ->(q) { where 'to_tsquery(:config, :query) @@ tsv', config: SEARCH_CONFIG, query: q }

  def update_index!
    values_sql = []
    weights = []

    unless destroyed?
      searchable.index_data.each do |weight, field_proc|
        weight = weight.to_s.upcase
        raise "illegal weight key #{weight}" unless WEIGHTS.include?(weight)
        value_sql = "'#{field_proc.call(searchable.id)}'"
        values_sql << value_sql
        weights << self.class.connection.quote(weight)
      end
    end

    values_sql_array = "Array[#{values_sql.join(', ')}]::text[]"
    weights_sql_array = "Array[#{weights.join(', ')}]::char[]"
    sql = "SELECT update_search_data('#{SEARCH_CONFIG}', '#{WORD_CONFIG}', #{id}, #{values_sql_array}, #{weights_sql_array})"
    self.class.connection.execute(sql)
  end
end
