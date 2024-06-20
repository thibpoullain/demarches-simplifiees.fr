#!/bin/bash

# Récupérer les migrations de db (db:migrate) et de données (after_party) non effectuées
skiped_migrations_file="db/skipped_migrations/migration.txt"
skiped_after_party_file="db/skipped_migrations/after_party.txt"

skiped_migrations=$(<"$skiped_migrations_file")
skiped_after_party=$(<"$skiped_after_party_file")

db_migrations=$(bin/rake db:migrate:status | awk '/^  down/{print $2",00_db_migrate"}' | while read -r line; do
  migration_id=${line%,*}
  if ! grep -q "$migration_id" <<< "$skiped_migrations"; then
    echo "$line"
  fi
done)

data_migrations=$(bin/rake after_party:status | awk '/^  down/{print $1",01_after_party"}' | while read -r line; do
  migration_id=${line%,*}
  if ! grep -q "$migration_id" <<< "$skiped_after_party"; then
    echo "$line"
  fi
done)

# Fusionner et trier les migrations par date
migrations=$(echo "$db_migrations $data_migrations" | tr ' ' '\n' | sort)

echo " ✨ Migrations à appliquer :"
echo "$migrations" | awk -F',' '{print $1}'

# Appliquer les migrations dans l'ordre
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
