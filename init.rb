Redmine::Plugin.register :redmine_postgresql_search do
  name 'Redmine PostgreSQL Search Plugin'
  url  'https://electric-things.com/redmine_postgresql'

  description 'This plugin adds advanced fulltext search capabilities to Redmine. PostgreSQL required.'

  author     'Jens Krämer, Electric Things Ltd.'
  author_url 'https://electric-things.com/'

  version '1.0.0'

  requires_redmine version_or_higher: '3.1.0'
end

Rails.configuration.to_prepare do
  if Redmine::Database.postgresql?
    RedminePostgresqlSearch.setup
  else
    'You are not using PostgreSQL. The redmine_postgresql_search plugin will not do anything.'
  end
end
