module RedminePostgresqlSearch
  class Tokenizer
    ALLOW_FOR_EXACT_SEARCH = '\@|_|\-|\.|\#|\%'.freeze

    class << self
      # extract tokens from the question
      # eg. hello "bye bye" => ["hello", "bye bye"]
      def build_tokens(question)
        tokens = question.scan(/((\s|^)"[^"]+"(\s|$)|\S+)/).collect { |m| m.first.gsub(/(^\s*"\s*|\s*"\s*$)/, '') }
        return [] if tokens.empty?

        @force_regular_search = false
        [sanitize_query_tokens(tokens), @force_regular_search]
      end

      def search_token(token)
        token = token.to_s
        exact_search_token?(token) ? token[1..-1] : token
      end

      def exact_search_token?(token)
        token[0] == '+'
      end

      private

      def force_regular_search?(token)
        return true if @force_regular_search

        # allow ip address search
        @force_regular_search = true if token =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\./ ||
                                        # allow mac address search
                                        token =~ /([0-9A-Fa-f]{2}[:-]){4}([0-9A-Fa-f]{2})/ ||
                                        # allow mail like search
                                        token =~ /[[:alnum:]._-]+@[[:alnum:].-]+/ ||
                                        # token with | cannot be used with tsearch
                                        token =~ /.*\|.*/

        @force_regular_search
      end

      # TODO: at the moment this breaks phrase search
      def sanitize_query_tokens(tokens)
        rc = Array(tokens).map do |token|
          s_token = search_token(token)
          if force_regular_search? s_token
            s_token
          else
            parts = if exact_search_token?(token)
                      s_token.split(/[^([:alnum:]\*|#{Tokenizer::ALLOW_FOR_EXACT_SEARCH})]+/)
                    else
                      s_token.split(/[^[:alnum:]\*]+/)
                    end

            parts.select! { |w| w.present? && w.length > 1 }
            parts
          end
        end

        rc.flatten!
        # Rails.logger.debug "debug token result: #{rc.inspect} "
        rc.uniq
      end
    end

    def initialize(record, mapping = {})
      @record = record
      @mapping = mapping
    end

    def index_data
      {}.tap do |data|
        @mapping.each do |weight, fields|
          data[weight] = get_value_for_fields fields
        end
      end
    end

    private

    def normalize_string(string)
      self.class.search_token(string).gsub(/[^([:alnum:]|#{Tokenizer::ALLOW_FOR_EXACT_SEARCH})]+/, ' ')
    end

    def get_value_for_fields(fields)
      Array(fields).map do |f|
        normalize_string(
          if f.respond_to?(:call)
            @record.instance_exec(&f)
          else
            @record.send(f)
          end
        )
      end.join ' '
    end
  end
end
