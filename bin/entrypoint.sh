#!/usr/bin/env bash

echo "Démarrage du container avec commande $*"

creer_db() {
  bin/rails db:schema:load
}

precompile_assets() {
  VERSION_ID=`cat version.txt`
  echo "Précompilation des assets de la version d'id $VERSION_ID"

  # Au préalable, suppression des assets de la précédente version
  rm -Rf /opt/ds/public/assets
  rm -Rf /opt/ds/public/packs

  #Précompilation des nouveaux assets : html, css, js, mails par défaut
  bin/rails assets:precompile

  #Recopie des assets portés par le code d'origine (ex : pages 404, police, pays.json...)
  cp -rp /opt/ds/public_src/* /opt/ds/public
}

migrate_db_and_data() {

  # Application d'une migration "retour vers le futur" (tagguée "juin 2021" mais en réalité, a été poussée après novembre 2021)
  # Pour éviter un rollback / comportement erratique, on applique cette migration (sans effet si déjà appliquée)...
  # ... avant de reprendre un ordre + logique (calculé par les commandes d'après)
  bin/rails db:migrate:up VERSION=20210630101808

  # Lister les migrations de db (db:migrate) et de données (after_party) qui n'ont pas encore été effectuée sur l'instance
  # Tri par date croissante
  # Obtention d'une liste type :
  # 20220405163206,00_db_migrate 20220407081538,00_db_migrate 20220408100411,01_after_party ...
  migrations=$(( bin/rake db:migrate:status | grep down | grep -oP '([0-9]){14}' | sed 's/$/,00_db_migrate/' ; bin/rake after_party:status | grep down | grep -oP '([0-9]){14}' | sed 's/$/,01_after_party/') | cat | sort)

  echo "Migrations (schéma et données) à appliquer : "
  echo $migrations

  # Itération pour application des migrations, dans l'ordre donné
  # Une erreur de migration de schéma est BLOQUANTE
  # Une erreur de migration de données ne l'est pas (la migration se poursuit ; une analyse humaine est alors à prévoir)
  # En cas d'erreur des commandes rails, les logs apparaissent dans la sortie standard + reversées sur Sentry (si configuré)
  for migration in $migrations ; do
    # Itération sur les espaces (couple id / type) puis "split" sur la virgule
    id_migration=${migration%,*};
    type_migration=${migration#*,};
    echo "Application de la migration $id_migration ($type_migration)"

    if [[ "$type_migration" = "00_db_migrate" ]]
    then
      # Une erreur de migration est bloquante
      if ! bin/rails db:migrate VERSION=$id_migration; then
        echo "Erreur lors de la migration de schéma $id_migration. Analyse humaine nécessaire."
        exit 1
      fi
    elif [[ "$type_migration" = "01_after_party" ]]
    then
      bin/rake after_party:run_version VERSION=$id_migration
      echo "Code retour after party : $?"
    fi
    #sinon, ignorer
  done
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
  echo " - migrate_db_and_data : migration de la BDD (nouvelles tables, colonnes, indexes, ...) et données"
  echo " - precompile_assets : precompilation des assets JS / HTML"
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
