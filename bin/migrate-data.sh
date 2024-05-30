#!/bin/bash

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
