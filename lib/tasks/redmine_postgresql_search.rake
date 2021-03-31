# frozen_string_literal: true

namespace :redmine_postgresql_search do
  desc 'Reindexes all searchable models (delete/create)'
  task rebuild_index: :environment do
    RedminePostgresqlSearch.rebuild_indices
  end

  desc 'Updates search index for all searchable models'
  task update_index: :environment do
    RedminePostgresqlSearch.update_indices
  end
end
