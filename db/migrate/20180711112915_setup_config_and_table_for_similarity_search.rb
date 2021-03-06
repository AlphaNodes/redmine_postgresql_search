# frozen_string_literal: true

class SetupConfigAndTableForSimilaritySearch < ActiveRecord::Migration[4.2]
  def up
    language = ENV['language'] || 'english'
    config_name = FulltextIndex::WORD_CONFIG

    enable_extension 'pg_trgm'

    drop_table :fulltext_words, if_exists: true
    add_column :fulltext_indices, :words, :string, array: true
    execute %{CREATE TABLE fulltext_words (word text NOT NULL UNIQUE, ndoc integer)}

    execute <<-SQL.squish
      CREATE TEXT SEARCH DICTIONARY #{config_name} (
          TEMPLATE = simple,
          stopwords = #{language}
      );

      CREATE TEXT SEARCH CONFIGURATION #{config_name} (
          COPY = pg_catalog.simple
      );

      ALTER TEXT SEARCH CONFIGURATION #{config_name} DROP MAPPING FOR int,
      sfloat,
      uint,
      float;

      ALTER TEXT SEARCH CONFIGURATION #{config_name} ALTER MAPPING FOR asciiword,
      asciihword,
      hword_asciipart,
      word,
      hword,
      hword_part,
      numword,
      numhword WITH #{config_name};
    SQL

    execute %{CREATE INDEX fulltext_words_trgm_idx ON fulltext_words USING gin (word gin_trgm_ops)}
    execute %{CREATE UNIQUE INDEX fulltext_words_idx ON fulltext_words (word)}
  end

  def down
    config_name = FulltextIndex::WORD_CONFIG

    execute <<-SQL.squish
      DROP TEXT SEARCH CONFIGURATION IF EXISTS #{config_name};

      DROP TEXT SEARCH DICTIONARY IF EXISTS #{config_name};
    SQL

    drop_table :fulltext_words, if_exists: true
    remove_column :fulltext_indices, :words, :string, array: true
  end
end
