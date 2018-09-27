module RedminePostgresqlSearch
  class Tokenizer
    def initialize(record, mapping = {})
      @record = record
      @mapping = mapping
    end

    def self.normalize_string(string)
      string.to_s.gsub(/[^[:alnum:]]+/, ' ')
    end

    # extract tokens from the question
    # eg. hello "bye bye" => ["hello", "bye bye"]
    def self.build_tokens(question)
      tokens = question.scan(/((\s|^)"[^"]+"(\s|$)|\S+)/).collect { |m| m.first.gsub(/(^\s*"\s*|\s*"\s*$)/, '') }
      return [] if tokens.empty?

      Tokenizer.sanitize_query_tokens(tokens)
    end

    # TODO: at the moment this breaks phrase search
    def self.sanitize_query_tokens(tokens)
      Array(tokens).map do |token|
        token.to_s.split(/[^[:alnum:]\*]+/).select { |w| w.present? && w.length > 1 }
      end.flatten.uniq
    end
  end
end
