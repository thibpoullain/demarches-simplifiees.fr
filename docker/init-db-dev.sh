#!/bin/bash
set -e
echo "création database tps_test et user tps_test pour environnement dev"

source /docker-entrypoint-initdb.d/dev.env.mandatory

psql -v ON_ERROR_STOP=1 --username $DB_USERNAME --dbname $DB_DATABASE -A <<-EOSQL
    CREATE USER tps_test WITH PASSWORD 'tps_test' superuser;

    CREATE DATABASE tps_test;
    GRANT ALL PRIVILEGES ON DATABASE tps_test TO tps_test;

    CREATE DATABASE tps_test_;
    GRANT ALL PRIVILEGES ON DATABASE tps_test TO tps_test;
EOSQL

# Boucle pour créer les bases tps_test_1 à tps_test_15 pour parallel_spec
for i in {1..15}
do
    psql -v ON_ERROR_STOP=1 --username "$DB_USERNAME" --dbname "$DB_DATABASE" <<-EOSQL
        CREATE DATABASE tps_test_$i;
        GRANT ALL PRIVILEGES ON DATABASE tps_test_$i TO tps_test;
EOSQL
done

echo "Databases créées avec succès."
