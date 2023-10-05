.PHONY: build install run setup clean shell dbshell console dbconsole status dump load workers dbcreate dbinit

current_date := $(shell date '+%Y-%m-%d-%H:%M:%S')
postgres_dump := production.dump
postgres_role := tps_development
postgres_database := tps_development

# How to use the Makefile

# To install and run the application with an empty database, do:
# 1. make install
# 2. make setup
# 3. make run

# The database will contain the seed user:
# user: test@exemple.fr
# password: 'this is a very complicated password !'
# Connect your browser to http://localhost:3000

# To inspect the docker containers status
# 4. make status

# To stop the application
# 5. CONTROL C
# 6. make clean


# After the initial installation:

# Run the application
# 1. make run

# Examine the application status
# 2. make status

# Stop the application
# 3. CONTROL C in app terminal
# 4. make clean

# To work with the anonymized database from production stored in ../dumps/production.dump
# 1. make run
# 2. make restore
# 3. make shell
# 4. in container shell
#    $ bin/migrate-data.sh
#    $ bin/rails db:seed

# To dump the local database to log/backup.sql
# make dump

# To load the local database from log/backup.sql
# make load

# To start the workers
# make workers

# To open a database shell and inspect the database container or use psql
# make dbshell


# Build the Docker image of the application
build:
	docker-compose build

# Create the Docker images for demat-social and install
install:
	echo "UID=$(shell id -u)" >> .env
	docker-compose build

# Install dependencies and setup the database
# Loads database schema and run seeds
setup:
	docker-compose run webapp-main bin/setup
	$(MAKE) clean

# Run the demat-social app
run:
	docker-compose up

# Cleanup the stopped Docker containers
clean:
	docker-compose down

# Open a bash shell inside the app container when app is running
# Can be used to inspect the container content or run the interactive Rails console
shell:
	docker exec -it demat-social-app /bin/bash

# Open a bash shell inside the database container when app is running
dbshell:
	docker exec -it demat-social-data /bin/bash

# Open a bash terminal inside the app container when app is not running
# Used for running data migration scripts or to run tests
# Properly override RAILS_ENV inside the container (development or test) as needed
console:
	docker-compose run --name webapp-console -e RAILS_ENV=development --rm  webapp-main /bin/bash

# Open a bash terminal inside the app container when app is not running
# Used for restoring a database from a dump or running psql
dbconsole:
	docker-compose run --name data-console -p 5432:5432 -e RAILS_ENV=development -e POSTGRES_USER=tps_development -e POSTGRES_PASSWORD=tps_development --rm  db

# Start the background jobs (workers and periodic jobs)
workers:
	docker exec -d demat-social-app bin/rails jobs:work
	docker exec -d demat-social-app bin/rails jobs:schedule

# List Docker containers
status:
	./docker/dlist

# Dump postgresql database - sql format
dump:
	docker exec -i demat-social-data /bin/bash -c "pg_dump -U $(postgres_role) $(postgres_database)" > log/backup.sql
	cp log/backup.sql log/backup-$(current_date).sql

# Load the application database from backup - sql format
# Warning: it will drop the current database
load:
	docker exec -i demat-social-data /bin/bash -c "dropdb -U $(postgres_role) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "psql -U $(postgres_role) $(postgres_database)" < log/backup.sql

# Restore the anonymized database from production - dump format
# First start database container in a terminal with 'make dbconsole'
# This allows to restore the database without having the web app running
# Warning: it will drop the current database
restore:
	docker cp ../dumps/$(postgres_dump) data-console:./
	docker exec -i data-console /bin/bash -c "dropdb --if-exists -U $(postgres_role) $(postgres_database)"
	docker exec -i data-console /bin/bash -c "createdb -U $(postgres_role) $(postgres_database)"
	docker exec -i data-console /bin/bash -c "pg_restore -U $(postgres_role) -d $(postgres_database) -x -O $(postgres_dump)"
	docker exec -i data-console /bin/bash -c "rm ./$(postgres_dump)"

# Drops the current development database and create a new empty one
# First start database container in a terminal with 'make dbconsole'
dbcreate:
	docker exec -i data-console /bin/bash -c "dropdb --if-exists -U $(postgres_role) $(postgres_database)"
	docker exec -i data-console /bin/bash -c "createdb -U $(postgres_role) $(postgres_database)"

# Reloads the database schema, runs the migrations, and seeds the database
dbinit:
	docker-compose run --name webapp-console -e RAILS_ENV=development --rm  webapp-main /bin/bash -c "bin/rails db:schema:load && bin/rails db:migrate && bin/rails db:seed"
