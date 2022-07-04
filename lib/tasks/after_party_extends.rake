namespace :after_party do
  desc 'Exécute la tâche after_party correspondante à la VERSION, seulement si elle n\'a jamais été jouée sur cette instance.'
  task :run_version do
    if ENV['VERSION']
      version_cible = ENV['VERSION']
    else
      raise 'La variable VERSION doit être spécifiée (ex : bin/rake after_party:run_to_version VERSION=20220405163206)'
    end

    # Spécifiquement à notre tâche -> tache pending (jamais jouée) ET timestamp correspondant à l'id de version mentionnée
    tache = AfterParty::TaskRecorder.pending_files.filter { |task| task.timestamp == version_cible }.map { |f| "after_party:#{f.task_name}" }
    if tache.empty?
      puts "Aucune tâche after_party exécutable correspondante à la version #{version_cible} (tâche non existante OU déjà jouée)."
      puts 'Vous pouvez exécuter bin/rake after_party:status pour lister les tâches after_party disponibles et leur statut d\'exécution'
    else
      puts "Exécution de la tâche #{tache}"
      Rake::Task[tache[0]].invoke
    end
  end
end
