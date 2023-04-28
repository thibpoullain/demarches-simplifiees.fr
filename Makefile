.PHONY: build install run setup clean shell dbshell console status dump load workers

current_date := $(shell date '+%Y-%m-%d-%H:%M:%S')
postgres_dump := ano_dds_1025749_230426.dump
postgres_role := tps_development
postgres_database := tps_development

# The first time app is installed, do:
# 1. make install
# 2. make setup
# 3. make run
# 4. make status
# 5. CONTROL C
# 6. make clean

# After the first installation, do:
# 1. make run
# 2. make status
# 3. stop with CONTROL C
# 4. make clean

# To dump the database in log/
# make dump

# To load the database from log/backup.sql
# make load

# Build the Docker image of the application
build:
	docker-compose build --no-cache

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
shell:
	docker exec -it demat-social-app /bin/bash

# Open a bash shell inside the database container when app is running
dbshell:
	docker exec -it demat-social-data /bin/bash

# Open a bash terminal inside the app container when app is not running
console:
	docker-compose run --rm  webapp-main /bin/bash

# Start the background jobs (workers)
workers:
	docker exec -it demat-social-app bin/rails jobs:work

# List Docker containers
status:
	./docker/dlist

# Dump postgresql database - sql format
dump:
	docker exec -i demat-social-data /bin/bash -c "pg_dump -U $(postgres_role) $(postgres_database)" > log/backup.sql
	cp log/backup.sql log/backup-$(current_date).sql

# Load the application database from backup - sql format
# It will drop the current database
load:
	docker exec -i demat-social-data /bin/bash -c "dropdb -U $(postgres_role) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "psql -U $(postgres_role) $(postgres_database)" < log/backup.sql

# Restore the anonymized database from production - dump format
# It will drop the current database
# tdb: run interlaced migrations and after_party tasks - customized script entrypoint.sh ?
restore:
		docker cp ../dumps/$(postgres_dump) demat-social-data:./
		docker exec -i demat-social-data /bin/bash -c "dropdb -U $(postgres_role) $(postgres_database)"
		docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role) $(postgres_database)"
		docker exec -i demat-social-data /bin/bash -c "pg_restore -U $(postgres_role) -d $(postgres_database) -x -O $(postgres_dump)"
		docker exec -i demat-social-data /bin/bash -c "rm ./$(postgres_dump)"
