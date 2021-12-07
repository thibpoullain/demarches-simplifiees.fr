#!/bin/bash
set -e
echo "création database tps_test et user tps_test pour environnement dev"

source /docker-entrypoint-initdb.d/dev.env.mandatory

psql -v ON_ERROR_STOP=1 --username $DB_USERNAME --dbname $DB_DATABASE -A <<-EOSQL
    CREATE DATABASE tps_test;
    CREATE USER tps_test WITH PASSWORD 'tps_test' superuser;
    GRANT ALL PRIVILEGES ON DATABASE tps_test TO tps_test;
EOSQL