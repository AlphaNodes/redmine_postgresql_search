DROP FUNCTION IF EXISTS update_search_data(regconfig,regconfig,integer,text[],character[]) CASCADE;

CREATE OR REPLACE FUNCTION extract_words (text text, word_config regconfig)
    RETURNS SETOF text
    LANGUAGE plpgsql STABLE
AS $f$
BEGIN
    RETURN QUERY
    SELECT
        word
    FROM
        -- allow alphanumeric characters and dots, everything else is replaced by whitespace
        ts_stat(format('SELECT to_tsvector(%s, %s) ', quote_literal(word_config), quote_literal(regexp_replace(text, '[^[:alnum:]].', ' ', 'g'))))
    WHERE
        length(word) > 4;
END;
$f$;

CREATE OR REPLACE FUNCTION increase_occurence_count (words text [ ])
    RETURNS void
    LANGUAGE plpgsql
AS $f$
BEGIN
    INSERT INTO fulltext_words
    SELECT
        unnest(words), 1 ON CONFLICT (word)
        DO
        UPDATE
        SET
            ndoc = fulltext_words.ndoc + 1;
END;
$f$;

CREATE OR REPLACE FUNCTION decrease_occurence_count (words text [ ])
    RETURNS void
    LANGUAGE plpgsql
AS $f$
BEGIN
    UPDATE
        fulltext_words
    SET
        ndoc = ndoc - 1
    WHERE
        word IN (
            SELECT
                unnest(decrease_occurence_count.words));
END;
$f$;

CREATE OR REPLACE FUNCTION update_wordlist (previous_words text [ ], current_words text [ ])
    RETURNS void
    LANGUAGE plpgsql
AS $f$
DECLARE
    added_words text [ ];
    removed_words text [ ];
BEGIN
    added_words := ARRAY (
        SELECT
            unnest(current_words)
        EXCEPT
        SELECT
            unnest(previous_words));
    removed_words := ARRAY (
        SELECT
            unnest(previous_words)
        EXCEPT
        SELECT
            unnest(current_words));
    -- RAISE NOTICE 'added words: %', added_words;
    -- RAISE NOTICE 'removed words: %', removed_words;
    RAISE NOTICE 'added words: %', array_length(added_words, 1);
    RAISE NOTICE 'removed words: %', array_length(removed_words, 1);
    PERFORM
        decrease_occurence_count (removed_words);
    PERFORM
        increase_occurence_count (added_words);
END;
$f$;

CREATE OR REPLACE FUNCTION texts_to_tsvector (search_config regconfig, texts text [ ], weights char [ ])
    RETURNS tsvector
    LANGUAGE plpgsql STABLE
AS $f$
DECLARE
    tsvector tsvector = '';
    text text;
    weight "char";
BEGIN
    FOR text,
    weight IN
    SELECT
        unnest(texts),
        unnest(weights)
        LOOP
            tsvector := tsvector || setweight(to_tsvector(search_config::regconfig, quote_literal(text)), weight);
        END LOOP;
    RETURN tsvector;
END;
$f$;

CREATE OR REPLACE FUNCTION update_search_data (search_config regconfig, word_config regconfig, index_id integer, texts_sql text [ ], weights char [ ])
    RETURNS void
    LANGUAGE plpgsql
AS $f$
DECLARE
    previous_words text [ ];
    current_words text [ ];
    texts text [ ];
    sql text;
    txt text;
BEGIN
    FOR sql IN SELECT unnest(texts_sql) LOOP
        EXECUTE sql INTO txt;
        texts := array_append(texts, coalesce(txt, ''));
    END LOOP;

    UPDATE
        fulltext_indices
    SET
        tsv = texts_to_tsvector (search_config, texts, weights)
    WHERE
        id = index_id;
    SELECT
        words INTO previous_words
    FROM
        fulltext_indices
    WHERE
        id = index_id;
    current_words := ARRAY (
        SELECT
            extract_words (array_to_string(texts, ' '),
                word_config));
    PERFORM
        update_wordlist (previous_words,
            current_words);
    UPDATE
        fulltext_indices
    SET
        words = current_words
    WHERE
        id = index_id;
END;
$f$;
