.PHONY:	setup up down restart connect dblocal dbload-prod dbdump-dev dbload-dev local-ci linters rspec-unit rspec-system rspec-system-visual rspec-parallel-file postgres_role postgres_database postgres_test_database d-setup d-up d-down d-dbinit d-build d-build-env d-shell d-dbshell d-shell-standalone d-dbshell-standalone d-workers d-status d-dump d-load d-restore_prod d-dbcreate d-rspec d-local-ci d-linters d-rspec-unit d-rspec-system d-rspec-system-visual d-rspec-parallel-file postgres_role_docker postgres_database_docker postgres_test_database_docker d-shell-root d-shell-standalone d-dbshell-standalone d-rspec-unit d-rspec_system d-rspec_system-visual d-rspec-parallel-file d-shell-standalone d-dbshell-standalone

current_date := $(shell date '+%Y-%m-%d-%H:%M:%S')
postgres_dump := dds_anonymiser.sql
postgres_role := postgres
postgres_database := tps_development
postgres_test_database := tps_test_

UNAME_S := $(shell uname -s)

help: ## Display this help section, or the detail of a specific command : make help cmd=<command_name>
	@if [ -z "$(cmd)" ]; then \
		echo "\n 📖 Available commands \n"; \
		grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'; \
	else \
		echo "\n 📖 Detail of the command \n"; \
		sed -n "/^${cmd}:/,/^$$/p" $(MAKEFILE_LIST); \
	fi

# detect the OS and set commands accordingly
ifeq ($(UNAME_S),Darwin)
    INSTALL_CMD := brew install
    DB_SERVICE_CMD_START := brew services start postgresql@16
    DB_SERVICE_CMD_STOP := brew services stop postgresql@16
else ifeq ($(UNAME_S),Linux)
    INSTALL_CMD := sudo apt-get install
    DB_SERVICE_CMD_START := sudo systemctl start postgresql-16.service
    DB_SERVICE_CMD_STOP := sudo systemctl stop postgresql-16.service
endif


create-env-dev: ## Create the .env.development file if it does not exist.
# This command constructs a development environment file by combining mandatory and optional environment variable settings.
# It ensures that all necessary configurations are set for the development environment.
#
# exemple:
#
#		make create-env-special
#
	@if [ ! -f .env.development ]; then \
		touch .env.development; \
		cat .env.mandatory.example >> .env.development; \
		cat .env.optional.example >> .env.development; \
	fi
	@echo "🌏 .env.development created"

env:
	@awk -F= '!/^#/ && $$2 != "" {print $$1" = "$$2}' .env.development

###############################################
##### Local environment #######################
###############################################


setup: ## Setup the local development environment.
# This command installs necessary tools like tmux, ngrok, ImageMagick, PostgreSQL, PostGIS, and other dependencies.
# It also sets up the Ruby and Node.js environments, initializes the database with schemas and seeds, and installs all necessary gems and npm packages.
#
	@gem install bundler --conservative
	@bundle check || bundle install -j
	@node --version
	@yarn install
	@bundle exec rails db:setup
	@$(INSTALL_CMD) tmux overmind

setup-vite: ## Setup the Vite configuration for the local environment, desactivate the docker configuration.
	@cp config/vite.json.local config/vite.json

up: ## lauch all (or per service with arg proc=service_name) the local services needed to run the app
# job workers, Rails server, and ngrok tunneling. If no specific process is indicated, it sets up the environment
# and starts all components using tmuxinator.
# example:
#   make up proc=vite  # Starts the Vite development server
#   make up            # Sets up the environment and start all components with tmuxinator
#
	@if [ "$(proc)" = "vite" ]; then \
		tmux send-keys -t demat-social:vite.0 'bin/vite dev' C-m; \
	elif [ "$(proc)" = "job" ]; then \
		tmux send-keys -t demat-social:job.0 'bin/rake jobs:work' C-m; \
	elif [ "$(proc)" = "rails" ]; then \
		tmux send-keys -t demat-social:main.0 'RAILS_QUEUE_ADAPTER=delayed_job bin/rails server -p 3000' C-m; \
	elif [ "$(proc)" = "ngrok" ]; then \
		tmux send-keys -t demat-social:ngrok.0 'ngrok start --config=ngrok.yml demarches_sociales' C-m; \
	else \
		@$(MAKE) setup-vite; \
		tmuxinator start demat-social; \
	fi


down: ## Stop all (or per service with arg proc=service_name) the local services needed to run the app
# If no specific process is targeted, it stops all environments managed by tmuxinator.
# Usage: make down proc=<component_name>
# Example:
#
#		make down proc=rails - This will send a signal to gracefully stop the Rails server.
#
# If no proc is specified, all components will be stopped.
#
	@if [ "$(proc)" = "vite" ]; then \
		tmux send-keys -t demat-social:vite.0 C-c; \
	elif [ "$(proc)" = "job" ]; then \
		tmux send-keys -t demat-social:job.0 C-c; \
	elif [ "$(proc)" = "rails" ]; then \
		tmux send-keys -t demat-social:main.0 C-c; \
	elif [ "$(proc)" = "ngrok" ]; then \
		tmux send-keys -t demat-social:ngrok.0 C-c; \
	else \
		tmuxinator stop demat-social; \
	fi


restart: ## Restart all (or per service with arg proc=service_name) the local services needed to run the app
# This command stops and immediately restarts various components (Vite, background jobs, Rails server, or Ngrok) based on the specified 'proc' variable.
# If no specific process is targeted, it restarts all components using scripted tmux key sequences.
# Usage: make restart proc=<component_name>
# Example:
#
#		make restart proc=vite - This command will stop and restart the Vite server.
#
# If no proc is specified, all configured processes are restarted.
#
	@if [ "$(proc)" = "vite" ]; then \
		tmux send-keys -t demat-social:vite.0 C-c; \
		tmux send-keys -t demat-social:vite.0 'bin/vite dev' C-m; \
	elif [ "$(proc)" = "job" ]; then \
		tmux send-keys -t demat-social:job.0 C-c; \
		tmux send-keys -t demat-social:job.0 'bin/rake jobs:work' C-m; \
	elif [ "$(proc)" = "rails" ]; then \
		tmux send-keys -t demat-social:main.0 C-c; \
		tmux send-keys -t demat-social:main.0 'RAILS_QUEUE_ADAPTER=delayed_job bin/rails server -p 3000' C-m; \
	elif [ "$(proc)" = "ngrok" ]; then \
		tmux send-keys -t demat-social:ngrok.0 C-c; \
		tmux send-keys -t demat-social:ngrok.0 'ngrok start --config=ngrok.yml demarches_sociales' C-m; \
	else \
		tmux send-keys -t demat-social:vite.0 C-c; \
		tmux send-keys -t demat-social:vite.0 'bin/vite dev' C-m; \
		tmux send-keys -t demat-social:job.0 C-c; \
		tmux send-keys -t demat-social:job.0 'bin/rake jobs:work' C-m; \
		tmux send-keys -t demat-social:main.0 C-c; \
		tmux send-keys -t demat-social:main.0 'RAILS_QUEUE_ADAPTER=delayed_job bin/rails server -p 3000' C-m; \
	fi


dbreset: ## Resets the development database to its initial state and sets up the necessary database structures.
# This command drops the existing database, recreates it, and then populates it according to the defined schema and seeds.
# Additionally, it prepares the database for parallel test execution.
# Usage:
#
#		make dbreset
#
	bundle exec rails db:reset
	bundle exec rake parallel:create


dblocal: ## Controls the local database service to either start or stop.
# This command toggles the state of the PostgreSQL service using predefined system commands.
# Usage:
#
#		make dblocal c=START to start the database, and make dblocal c=STOP to stop the database.
#
	@$(DB_SERVICE_CMD_$(c))


dbload-prod: ## Loads a production database dump into the tps_development_prod database.
# it is an other database than the normal development database
# Useful for loading real data into an second local database to test against production-like data.
# It will run the data migration defined in the bin/migrate-data.sh script.
# Usage:
#
# 	make dbload-prod
#
	@cp ../dumps/$(postgres_dump) ./
	@psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS tps_development_dump_prod;"
	@psql -U postgres -d postgres -c "CREATE DATABASE tps_development_dump_prod;"
	@psql -U $(postgres_role) -d tps_development_dump_prod -f $(postgres_dump)
	@rm ./$(postgres_dump)
	@bin/migrate-data.sh
	@$(MAKE) use-dbprod
	@bin/rails db:seed

use-dbprod: ## Switches the connection string in the .env.development to use the production dump database.
# Use this after loading a production dump to point your application to the right database.
# Usage: make use-dbprod
# Example:
#
#		make use-dbprod - Modifies the .env file to use the development database loaded from the production dump.
	@echo "\n 💾 Using the production dump database"
	@sed -i '' 's/tps_development/tps_development_dump_prod/g' config/database.yml

use-dbdev: ## Sets the database connection in the .env.development back to the default development database.
# Usage: make use-dbdev
# Example:
#
# 	make use-dbdev - Resets the development database environment variable.
	@echo "\n 💾 Using the dev database"
	@sed -i '' 's/tps_development_dump_prod/tps_development/g' config/database.yml

dbdump-dev: ## Dumps the current state of the development database into log/backup.sql.
# It also keeps a timestamped backup copy for reference.
# Usage: make dbdump-dev
# Example:
#
#		make dbdump-dev - Creates a PostgreSQL dump of your current development database for backup or migration purposes.
#
	@pg_dump -U $(postgres_role) $(postgres_database) > log/backup.sql
	@cp log/backup.sql log/backup-$(current_date).sql

dbload-dev: ## Loads a previously dumped SQL file into the development database.
# Restores your development environment from backup if needed.
# Usage: make dbload-dev
# Example:
#
#		make dbload-dev - Restores your development database from a predetermined backup SQL file.
#
	@bundle exec rails db:drop
	@bundle exec rails db:create
	@psql -U $(postgres_role) $(postgres_database) < log/backup.sql

local-ci: ## Runs the entire local CI workflow, invoking linting, unit, and system tests in parallel.
# This allows for comprehensive testing of the software on a local machine to mimic CI server operations.
# Usage: make local-ci nb_workers=<number_of_workers>
# Example:
#
#		make local-ci nb_workers=4 - Executes linters and tests using 4 parallel workers for speed.
#
	@$(MAKE) linters
	@$(MAKE) rspec-unit nb_workers=$(nb_workers)
	@$(MAKE) rspec-system nb_workers=$(nb_workers)

linters: ## Runs lint checks on the codebase.
	bundle exec rake lint

rspec-unit: ## Executes unit tests using the parallel_rspec tool to speed up the test process.
# This command categorizes and runs unit tests across different specs in parallel based on previous runtime logs, optimizing the testing process on successive runs.
# It first checks if a runtime log exists to follow an optimized test executing order; if not, it creates a new runtime log.
#
# Usage: make rspec-unit nb_workers=<number_of_workers>
#
# Example:
#
#		make rspec-unit nb_workers=4 - Runs unit tests across four parallel processes, either in an optimized order if previous logs exist or initializes a comprehensive run if it's a first-time setup.
#
	@if [ ! -e ./config/parallel_runtime_rspec_unit_test.log ]; then \
		echo '✨ first launch'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --exclude-pattern 'spec/system/.*_spec.rb' --test-options "--format ParallelTests::RSpec::RuntimeLogger --out ./config/parallel_runtime_rspec_unit_test.log"; \
		echo '\n 🟢 system test suite over'; \
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

rspec-system: ## Executes system tests using the parallel_rspec tool, effectively speeding up testing by running multiple tests in parallel.
# This command initially cleans up Capybara temporary files to prevent tests from being affected by stale data.
# Depending on whether a runtime log exists, it either conducts a full refresh of all system tests or runs them in an optimized sequence based on previous test durations to minimize total run time.
# Usage: make rspec-system nb_workers=<number_of_workers>
#
# Example:
# 	make rspec-system nb_workers=4
#
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

rspec-system-visual: ## Executes a single system test file in a visual mode, allowing browsers to be visible during the test which aids in debugging.
# This command is useful when detailed observation of the UI flow is needed or for demonstration purposes.
# exemple :
#		make rseq-system-visual file=<file_path>
#
	MAKE_IT_SLOW=true NO_HEADLESS=1 bundle exec rspec $(file)

rspec-system-file: ## Runs a specified RSpec test file without the headless mode, useful for quick checks or during development.
# This command executes the test usually more quickly as it avoids overhead related to visual rendering.
# exemple:
#		make rspec-system-file file=<file_path>
#
	MAKE_IT_SLOW=false NO_HEADLESS=0 bundle exec rspec $(file)

rspec-parallel-file: ## Executes RSpec tests in parallel on a specific file, enhancing test execution speed by distributing workload.
# This command is especially useful for larger test files or suites where parallel execution can significantly reduce runtime.
# Usage:
#		make rspec-parallel-file nb_workers=<number_of_workers> file=<file_path>
#
	bundle exec parallel_rspec -n $(nb_workers) -t rspec $(file) --test-options "--format progress"


###############################################
##### docker environment ######################
###############################################

postgres_role_docker := tps_development

d-setup: ## Sets up the development environment in Docker.
# This command installs Docker if not present, sets up the environment files, initializes the Docker-compose database service, and runs all necessary database setup scripts.
# It completely prepares your Dockerized development environment to be up and running.
#
# Example:
#
#		make d-setup
#
	@$(DB_SERVICE_CMD_STOP)
	@chmod -R +x docker/init-db-dev.sh
	@$(MAKE) d-build
	@$(MAKE) d-dbinit

d-setup-vite: ## Sets up the Vite configuration for the Docker environment.
# This command copies the Vite configuration file for Docker to the local environment.
#
	@cp config/vite.json.docker config/vite.json

d-up: ## Starts the Docker environment with the application and database services.
	@$(DB_SERVICE_CMD_STOP)
	docker-compose up

d-down: ## Stop and cleanup the stopped Docker containers
	docker-compose down

d-dbinit: ## Reloads the database schema, runs the migrations, and seeds the database
	docker-compose run -u demat-social --name webapp-console -e RAILS_ENV=development --rm  webapp-main /bin/bash -c "bin/rails db:schema:load && bin/rails db:seed"
	@$(MAKE) d-down

d-build: ## Build the Docker image of the application
	docker-compose build

d-build-env: ## Create the Docker images for demat-social and install
	echo "UID=$(shell id -u)" >> .env
	docker-compose build

d-shell: ## Open a bash shell inside the app container when app is running
# Can be used to inspect the container content or run the interactive Rails console
#
	docker exec -it -u demat-social demat-social-app /bin/bash

d-shell-root: ## Open a bash shell inside the app container as root when app is running
	docker exec -it -u root -social demat-social-app /bin/bash

d-dbshell: ## Open a bash shell inside the database container when app is running
	docker exec -it demat-social-data /bin/bash

d-shell-standalone: ## open a standalone web container with the app
# it uses the already opened database container
# use like this : make shell-test-standalone env=test user=demat-social
#
	docker-compose run -u $(user) -e RAILS_ENV=$(env) --rm  webapp-main /bin/bash

d-dbshell-standalone: ## Open a bash terminal inside the app container when app is not running
# Used for restoring a database from a dump or running psql
#
	docker-compose run -p 5432:5432 -e RAILS_ENV=development -e POSTGRES_USER=tps_development -e POSTGRES_PASSWORD=tps_development --rm  db

d-workers: ## Start the background jobs (workers and periodic jobs)
	docker exec -d demat-social-app bin/rails jobs:work
	docker exec -d demat-social-app bin/rails jobs:schedule

d-status: ## List Docker containers
	./docker/dlist

d-dump: ## Dump postgresql database - sql format
	docker exec -i demat-social-data /bin/bash -c "pg_dump -U $(postgres_role_docker) $(postgres_database)" > log/backup.sql
	cp log/backup.sql log/backup-$(current_date).sql

d-load: ## Load the application database from backup - sql format
# Warning: it will drop the current database
#
	docker-compose stop webapp-main
	docker exec -i demat-social-data /bin/bash -c "dropdb -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "psql -U $(postgres_role_docker) $(postgres_database)" < log/backup.sql
	docker-compose restart webapp-main

d-restore_prod: ## Restore the anonymized database from production - dump format
# First start database container
# Warning: it will drop the current database
#
	docker-compose stop webapp-main
	docker cp ../dumps/$(postgres_dump) demat-social-data:./
	docker exec -i demat-social-data /bin/bash -c "dropdb --if-exists -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "pg_restore -U $(postgres_role_docker) -d $(postgres_database) -x -O $(postgres_dump)"
	docker exec -i demat-social-data /bin/bash -c "rm ./$(postgres_dump)"
	docker-compose restart webapp-main
	docker exec -i demat-social-app /bin/bash -c "bin/migrate-data.sh"
	docker exec -i demat-social-app /bin/bash -c "bin/rails db:seed"

d-dbcreate: ## Drops the current development database and create a new empty one
# First start database container in a terminal with 'make dbconsole'
#
	docker exec -i demat-social-data /bin/bash -c "dropdb --if-exists -U $(postgres_role_docker) $(postgres_database)"
	docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role_docker) $(postgres_database)"

d-rspec: ## Run the rspec tests
	docker-compose run -u demat-social --name webapp-test -e RAILS_ENV=test --rm webapp-main bundle exec rspec --color $(file)

d-local-ci: ## Run the local CI workflow in Docker, including linters, unit, and system tests in parallel.
	@$(MAKE) d-linters
	@$(MAKE) d-rspec-unit nb_workers=$(nb_workers)
	@$(MAKE) d-rspec-system nb_workers=$(nb_workers)

d-linters: ## Run the linters in Docker
	docker-compose run -u demat-social --name webapp-test-linters -e RAILS_ENV=test --rm webapp-main bundle rake lint

d-rspec-unit: ## Run the unit tests in Docker, ex : make d-rspec-unit nb_workers=4
	docker-compose run -u demat-social --name webapp-test-smalls -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(components|graphql|helpers|middlewares|mailers|policies|serializers)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-jobs-lib -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(jobs|lib)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-controllers -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(controllers)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-models -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(models)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-views -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(views)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-services -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(services)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;
	docker-compose run -u demat-social --name webapp-test-lonely -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log;

d-rspec_system: ## Run the system tests in Docker, ex : make d-rspec_system nb_workers=4
	docker-compose run -u demat-social --name webapp-test-system-smalls -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(accessibilite|api_particulier|experts|france_connect|integrateurs|routing|session|misc)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
	docker-compose run -u demat-social --name webapp-test-system-instructeurs -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(instructeurs)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
	docker-compose run -u demat-social --name webapp-test-system-administrateurs -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(administrateurs)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
	docker-compose run -u demat-social --name webapp-test-system-users -e RAILS_ENV=test webapp-main bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(users)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
