.PHONY:	setup up down restart connect dblocal dbload-prod dbdump-dev dbload-dev local-ci linters rspec-unit rspec-system rspec-system-visual rspec-parallel-file postgres_role postgres_database postgres_test_database d-setup d-up d-down d-dbinit d-build d-build-env d-shell d-dbshell d-shell-standalone d-dbshell-standalone d-workers d-status d-dump d-load d-restore_prod d-dbcreate d-rspec d-local-ci d-linters d-rspec-unit d-rspec-system d-rspec-system-visual d-rspec-parallel-file postgres_role_docker postgres_database_docker postgres_test_database_docker d-shell-root d-shell-standalone d-dbshell-standalone d-rspec-unit d-rspec_system d-rspec_system-visual d-rspec-parallel-file d-shell-standalone d-dbshell-standalone

current_date := $(shell date '+%Y-%m-%d-%H:%M:%S')
postgres_dump := production.dump
postgres_role := postgres
postgres_database := tps_development
postgres_test_database := tps_test_

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
    INSTALL_CMD := brew install
    DB_SERVICE_CMD_START := brew services start postgresql@16
    DB_SERVICE_CMD_STOP := brew services stop postgresql@16
else ifeq ($(UNAME_S),Linux)
    INSTALL_CMD := sudo apt-get install
    DB_SERVICE_CMD_START := sudo systemctl start postgresql-16.service
    DB_SERVICE_CMD_STOP := sudo systemctl stop postgresql-16.service
endif


###############################################
##### Local environment #######################
###############################################

# can be run multiple times without issue
setup:
	@gem install bundler --conservative
	@bundle check || bundle install -j
	@node --version
	@yarn install
	@bundle exec rails db:setup
	@$(INSTALL_CMD) tmux overmind

up:
	@$(DB_SERVICE_CMD_START)
	overmind start --any-can-die -f Procfile.dev

down:
	@$(DB_SERVICE_CMD_STOP)
	overmind quit

restart:
	overmind restart

connect:
	overmind connect

# ex : make dblocal c=START/STOP
dblocal:
	@$(DB_SERVICE_CMD_$(c))

dbload-prod:
	[ -e ./.overmind.sock ] && overmind stop || true
	@cp ../dumps/$(postgres_dump) ./
	@bundle exec rails db:drop
	@bundle exec rails db:create
	@pg_restore -U $(postgres_role) -d $(postgres_database) -x -O $(postgres_dump)
	@rm ./$(postgres_dump)
	@bin/migrate-data.sh
	@bin/rails db:seed
	[ -e ./.overmind.sock ] && overmind restart || true

dbdump-dev:
	@[ -e ./.overmind.sock ] && overmind stop || true
	@pg_dump -U $(postgres_role) $(postgres_database) > log/backup.sql
	@cp log/backup.sql log/backup-$(current_date).sql
	@[ -e ./.overmind.sock ] && overmind restart

dbload-dev:
	[ -e ./.overmind.sock ] && overmind stop || true
	@bundle exec rails db:drop
	@bundle exec rails db:create
	@psql -U $(postgres_role) $(postgres_database) < log/backup.sql
	[ -e ./.overmind.sock ] && overmind restart

# ex : make local-ci nb_workers=2
local-ci:
	@$(MAKE) linters
	@$(MAKE) rspec-unit nb_workers=$(nb_workers)
	@$(MAKE) rspec-system nb_workers=$(nb_workers)

linters:
	bundle exec rake lint

rspec-unit:
	@$(DB_SERVICE_CMD_START)
	@if [ ! -e ./config/parallel_runtime_rspec_unit_test.log ]; then \
		echo '✨ first launch'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --exclude-pattern 'spec/system/.*_spec.rb' --test-options "--format ParallelTests::RSpec::RuntimeLogger --out ./config/parallel_runtime_rspec_unit_test.log"; \
	else \
		echo '🚀 optimised launch'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(components|graphql|helpers|middlewares|mailers|policies|serializers)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(lib)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(jobs)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(controllers)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(models)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(views)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(services)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
	fi

rspec-system:
	@rm -rf tmp/capybara/* && echo '🧹 clean capybara tmp files'
	@if [ ! -e ./config/parallel_runtime_rspec_system_test.log ]; then \
		echo '✨ first launch'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec spec/system/**/*_spec.rb --test-options "--format ParallelTests::RSpec::RuntimeLogger --out ./config/parallel_runtime_rspec_system_test.log"; \
	else \
		echo '🚀 optimised launch'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(accessibilite|api_particulier|experts|france_connect|integrateurs|routing|session|misc)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(instructeurs)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(administrateurs)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(users)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
	fi

rspec-system-visual:
	MAKE_IT_SLOW=true NO_HEADLESS=1 bundle exec rspec $(file)

rspec-parallel-file:
	bundle exec parallel_rspec -n $(nb_workers) -t rspec $(file) --test-options "--format progress"


###############################################
##### docker environment ######################
###############################################

postgres_role_docker := tps_development

d-setup:
	@$(DB_SERVICE_CMD_STOP)
	@$(MAKE) d-build
	@$(MAKE) d-dbinit

# Run the demat-social app, need the local database to be down
d-up:
	@$(DB_SERVICE_CMD_STOP)
	docker-compose up

# Cleanup the stopped Docker containers
d-down:
	docker-compose down

# Reloads the database schema, runs the migrations, and seeds the database
d-dbinit:
	docker-compose run -u demat-social --name webapp-console -e RAILS_ENV=development --rm  webapp-main /bin/bash -c "bin/rails db:schema:load && bin/rails db:seed"
	@$(MAKE) d-down

# Build the Docker image of the application
d-build:
	docker-compose build

# Create the Docker images for demat-social and install
d-build-env:
	echo "UID=$(shell id -u)" >> .env
	docker-compose build

# Open a bash shell inside the app container when app is running
# Can be used to inspect the container content or run the interactive Rails console
d-shell:
	docker exec -it -u demat-social demat-social-app /bin/bash

d-shell-root:
	docker exec -it -u root -social demat-social-app /bin/bash

# Open a bash shell inside the database container when app is running
d-dbshell:
	docker exec -it demat-social-data /bin/bash

# open a standalone web container with the app
# it uses the already opened database container
# use like this : make shell-test-standalone env=test user=demat-social
d-shell-standalone:
	docker-compose run -u $(user) -e RAILS_ENV=$(env) --rm  webapp-main /bin/bash

# Open a bash terminal inside the app container when app is not running
# Used for restoring a database from a dump or running psql
d-dbshell-standalone:
	docker-compose run -p 5432:5432 -e RAILS_ENV=development -e POSTGRES_USER=tps_development -e POSTGRES_PASSWORD=tps_development --rm  db

# Start the background jobs (workers and periodic jobs)
d-workers:
	docker exec -d demat-social-app bin/rails jobs:work
	docker exec -d demat-social-app bin/rails jobs:schedule

# List Docker containers
d-status:
	./docker/dlist

# Dump postgresql database - sql format
d-dump:
	docker exec -i demat-social-data /bin/bash -c "pg_dump -U $(postgres_role_docker) $(postgres_database)" > log/backup.sql
	cp log/backup.sql log/backup-$(current_date).sql

# Load the application database from backup - sql format
# Warning: it will drop the current database
d-load:
	docker-compose stop webapp-main
	docker exec -i demat-social-data /bin/bash -c "dropdb -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "psql -U $(postgres_role_docker) $(postgres_database)" < log/backup.sql
	docker-compose restart webapp-main

# Restore the anonymized database from production - dump format
# First start database container
# Warning: it will drop the current database
d-restore_prod:
	docker-compose stop webapp-main
	docker cp ../dumps/$(postgres_dump) demat-social-data:./
	docker exec -i demat-social-data /bin/bash -c "dropdb --if-exists -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "pg_restore -U $(postgres_role_docker) -d $(postgres_database) -x -O $(postgres_dump)"
	docker exec -i demat-social-data /bin/bash -c "rm ./$(postgres_dump)"
	docker-compose restart webapp-main
	docker exec -i demat-social-app /bin/bash -c "bin/migrate-data.sh"
	docker exec -i demat-social-app /bin/bash -c "bin/rails db:seed"

# Drops the current development database and create a new empty one
# First start database container in a terminal with 'make dbconsole'
d-dbcreate:
	docker exec -i demat-social-data /bin/bash -c "dropdb --if-exists -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role_docker) $(postgres_database)"

d-rspec:
	docker-compose run -u demat-social --name webapp-test -e RAILS_ENV=test --rm webapp-main bundle exec rspec --color $(file)

# ex : make local-ci nb_workers=2
d-local-ci:
	@$(MAKE) d-linters
	@$(MAKE) d-rspec-unit nb_workers=$(nb_workers)
	@$(MAKE) d-rspec-system nb_workers=$(nb_workers)

d-linters:
	docker-compose run -u demat-social --name webapp-test-linters -e RAILS_ENV=test --rm webapp-main bundle rake lint

# ex : make d-rspec-unit nb_workers=2
d-rspec-unit:
	docker-compose run -u demat-social --name webapp-test-smalls -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(components|graphql|helpers|middlewares|mailers|policies|serializers)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-jobs-lib -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(jobs|lib)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-controllers -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(controllers)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-models -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(models)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-views -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(views)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-services -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(services)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-lonely -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;

d-rspec_system:
	docker-compose run -u demat-social --name webapp-test-system-smalls -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(accessibilite|api_particulier|experts|france_connect|integrateurs|routing|session|misc)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
	docker-compose run -u demat-social --name webapp-test-system-instructeurs -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(instructeurs)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
	docker-compose run -u demat-social --name webapp-test-system-administrateurs -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(administrateurs)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
	docker-compose run -u demat-social --name webapp-test-system-users -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(users)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
