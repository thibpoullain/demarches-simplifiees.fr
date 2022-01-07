#!/usr/bin/env bash

echo "Démarrage du container avec commande $*"

creer_db() {
  bin/rails db:schema:load
}

deploy() {
  VERSION_ID=`cat version.txt`
  echo "Déploiement de la version d'id $VERSION_ID"

  #Application des changements de BDD de la version : nouvelles tables, colonnes & co
  bin/rails db:migrate

  # Au préalable, suppression des assets de la précédente version
  rm -Rf /opt/ds/public/assets
  rm -Rf /opt/ds/public/packs

  #Précompilation des nouveaux assets : html, css, js, mails par défaut
  bin/rails assets:precompile

  #Recopie des assets portés par le code d'origine (ex : pages 404, police, pays.json...)
  cp -rp /opt/ds/public_src/* /opt/ds/public
}

schedule_jobs() {
  echo "Ordonnancement des jobs"
  bundle exec rake jobs:schedule
  #Et démarrage du worker
  bin/rake jobs:work
}

start() {
  #Le cas échéant, création des répertoires nécessaires à l'applicatif
  mkdir -p tmp/pids

  #Démarrage du serveur d'application
  echo "Démarrage de l'instance $APP_HOST"
  bundle exec puma -C config/puma.rb
}

afficher_aide() {
  echo "Paramètres du script (cumulables) :"
  echo " - start : démarrage de l'application"
  echo " - deploy : déploiement de la version (le cas échéant migration de la BDD puis compilation des assets JS / HTML)"
  echo " - schedule_jobs : activation des jobs récurrents"
  echo " - init_schema *****Pour la première installation UNIQUEMENT ***** : SUPPRESSION / création des tables initiales"
}


for param in $@
do
  echo "Traitement du paramétre $param"
  case $param in
    help)
      afficher_aide
    ;;
    init_schema)
      creer_db
    ;;
    *)
      #Par defaut exécution de la commande passée en paramétre
      if ! $param;
      then
        echo "Erreur lors du traitement du paramétre $param ; abandon du démarrage du container" >&2
        exit 1
      fi
    ;;
  esac
done

exit 0
