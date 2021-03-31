# frozen_string_literal: true

raise "\n\033[31maredmine_postgresql_search requires ruby 2.6 or newer. Please update your ruby version.\033[0m" if RUBY_VERSION < '2.6'

Redmine::Plugin.register :redmine_postgresql_search do
  name 'Redmine PostgreSQL Search Plugin'
  url  'https://github.com/alphanodes/redmine_postgresql_search'
  description 'This plugin adds advanced fulltext search capabilities to Redmine. PostgreSQL required.'
  author 'AlphaNodes GmbH'
  author_url 'https://alphanodes.com/'
  version RedminePostgresqlSearch::VERSION
  requires_redmine version_or_higher: '4.1'

  begin
    requires_redmine_plugin :additionals, version_or_higher: '3.0.1'
  rescue Redmine::PluginNotFound
    raise 'Please install additionals plugin (https://github.com/alphanodes/additionals)'
  end

  settings default: Additionals.load_settings('redmine_postgresql_search'), partial: 'settings/postgresql_search/postgresql_search'
end

begin
  if ActiveRecord::Base.connection.table_exists?(Setting.table_name)
    Rails.configuration.to_prepare do
      if Redmine::Database.postgresql?
        RedminePostgresqlSearch.setup
      else
        'You are not using PostgreSQL. The redmine_postgresql_search plugin will not do anything.'
      end
    end
  end
rescue ActiveRecord::NoDatabaseError
  Rails.logger.error 'database not created yet'
end
