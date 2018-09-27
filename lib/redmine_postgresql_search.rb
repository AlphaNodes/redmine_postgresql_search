module RedminePostgresqlSearch
  def self.setup
    Rails.logger.info 'enabling advanced PostgreSQL search'

    SearchController.class_eval do
      prepend Patches::SearchController
    end

    Redmine::Search::Fetcher.class_eval do
      prepend Patches::Fetcher
    end

    @searchables = []

    setup_searchable Changeset,
                     mapping: { b: :comments },
                     last_modification_field: "#{Changeset.table_name}.committed_on"

    setup_searchable Document,
                     mapping: { a: :title, b: :description },
                     last_modification_field: "#{Document.table_name}.created_on"

    setup_searchable Issue,
                     mapping: { a: :subject, b: :description }

    setup_searchable Message,
                     mapping: { a: :subject, b: :content }

    setup_searchable News,
                     mapping: { a: :title, b: :summary, c: :description },
                     last_modification_field: "#{News.table_name}.created_on"

    setup_searchable WikiPage,
                     mapping: { a: :title, b: -> (id) { WikiPage.where(id: id).select(:text).joins(:content).to_sql } },
                     last_modification_field: "#{WikiContent.table_name}.updated_on"

    # Searchables that depend on another Searchable and cannot be searched separately.
    # They use the last modification field of their parents.

    setup_searchable Attachment,
                     mapping: { a: :filename, b: :description }

    setup_searchable CustomValue,
                     if: -> { customized.is_a?(Issue) },
                     mapping: { b: :value }

    setup_searchable Journal,
                     if: -> { journalized.is_a?(Issue) },
                     mapping: { b: :notes, c: -> (id) { Journal.where(id: id).select(:subject).joins(:issue).to_sql } }

    load 'redmine_postgresql_search/test_support.rb' if Rails.env.test?
  end

  def self.settings
    if Rails.version >= '5.2'
      Setting[:plugin_redmine_postgresql_search]
    else
      ActionController::Parameters.new(Setting[:plugin_redmine_postgresql_search])
    end
  end

  def self.setting?(value)
    return true if settings[value].to_i == 1

    false
  end

  def self.rebuild_indices

    ActiveRecord::Base.connection.execute("TRUNCATE fulltext_words RESTART IDENTITY")
    @searchables.each(&:rebuild_index)
  end

  def self.setup_searchable(clazz, options = {})
    @searchables << clazz
    clazz.class_eval do
      has_one :fulltext_index, as: :searchable, dependent: :delete
      if (condition = options[:if])
        define_method :add_to_index? do
          !!instance_exec(&condition)
        end
      else
        define_method :add_to_index? do
          true
        end
      end

      after_commit :update_fulltext_index

      mapping = options[:mapping]

      define_method :index_data do
        mapping.map do |weight, field|
        field_proc =
          if field.is_a?(Proc)
            field
          else
            -> (id) { clazz.where(id: id).select(field).to_sql }
          end
        [weight, field_proc]
        end.to_h
      end

      last_modification_field = options[:last_modification_field].presence || clazz.table_name + '.updated_on'

      define_singleton_method :last_modification_field do
        last_modification_field
      end

      prepend RedminePostgresqlSearch::Patches::Searchable::InstanceMethods
      extend RedminePostgresqlSearch::Patches::Searchable::ClassMethods
    end
  end
end
