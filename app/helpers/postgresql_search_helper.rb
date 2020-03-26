module PostgresqlSearchHelper
  def highlight_tokens(text, tokens)
    return super unless text && tokens && tokens.present?

    super
  end
end
