.PHONY: build install run setup clean shell console show dump load workers

current_date := $(shell date '+%Y-%m-%d-%H:%M:%S')

# The first time app is installed, do:
# 1. make install
# 2. make setup
# 3. make run
# 4. make show
# 5. CONTROL C
# 6. make clean

# After the first installation, do:
# 1. make run
# 2. make show
# 3. stop with CONTROL C
# 4. make clean

# To dump the database in log/
# make dump

# To load the database from log/backup.sql
# make load

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
shell:
	docker exec -it demat-social-app /bin/bash

# Open a bash terminal inside the app container when app is not running
console:
	docker-compose run --rm  webapp-main /bin/bash

# Start the background jobs (workers)
workers:
	docker exec -it demat-social-app bin/rails jobs:work

# List Docker containers
show:
	./docker/dlist

# Dump postgresql database
dump:
	docker exec -i demat-social-sql /bin/bash -c "pg_dump -U tps_development tps_development" > log/backup.sql
	cp log/backup.sql log/backup-$(current_date).sql

# Load the application database from backup
load:
	docker exec -i demat-social-sql /bin/bash -c "psql -U tps_development tps_development" < log/backup.sql
