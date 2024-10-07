MAKEFLAGS += --no-print-directory

.PHONY:	setup create-env-dev up down restart connect ngrok dblocal dbload-prod use-dbprod use-dbdev dbdump-dev dbload-dev local-ci linters rspec-unit rspec-system rspec-system-visual rspec-parallel-file d-setup d-up d-down d-dbinit d-build d-build-env d-shell d-shell-root d-dbshell d-dbshell-standalone d-workers d-status d-dump d-load d-restore_prod d-dbcreate d-rspec d-local-ci d-linters d-rspec-unit d-rspec_system d-shell-standalone d-dbshell-standalone d-setup-vite rspec-system-file

###############################################
##### Variable setup ##########################
###############################################

current_date := $(shell date '+%Y-%m-%d-%H:%M:%S')
postgres_dump := dds_anon.sql
postgres_role := postgres
postgres_database := tps_development
postgres_database_dump_prod := tps_development_dump_prod
postgres_test_database := tps_test_

UNAME_S := $(shell uname -s)

###############################################
##### Environment setup #######################
###############################################

# detect the OS and set some commands accordingly
ifeq ($(UNAME_S),Darwin)
    INSTALL_CMD := brew install
    INSTALL_DESKTOP_CMD := brew cask install
    DB_SERVICE_CMD_START := brew services start postgresql
    DB_SERVICE_CMD_STOP := brew services stop postgresql
else ifeq ($(UNAME_S),Linux)
    INSTALL_CMD := sudo apt-get install
    INSTALL_DESKTOP_CMD := sudo apt-get install
    DB_SERVICE_CMD_START := sudo systemctl start postgresql.service
    DB_SERVICE_CMD_STOP := sudo systemctl stop postgresql.service
endif

# setup the local environment
setup:
	@gem install bundler --conservative
	@bundle check || bundle install --deployment
	gem install tmuxinator
	@node --version
	@yarn install
	bundle exec rails db:setup
	bundle exec rake parallel:create
	psql -d tps_development -c "CREATE EXTENSION postgis;"
	$(MAKE) setup-capybara-drivers

# Setup a specific version of chrome suite for the tests
setup-capybara-drivers:
	$(eval version := 128.0.6613.119)
	$(eval UNAME_S := $(shell uname -s))
ifeq ($(UNAME_S),Darwin)
	@echo "⬇️ Downloading Chrome for Testing $(version) for Mac..."
	@curl -L --progress-bar https://storage.googleapis.com/chrome-for-testing-public/$(version)/mac-arm64/chrome-mac-arm64.zip -o chrome.zip
	@echo "⬇️ Downloading Chromedriver $(version) for Mac..."
	@curl -L --progress-bar https://storage.googleapis.com/chrome-for-testing-public/$(version)/mac-arm64/chromedriver-mac-arm64.zip -o chromedriver.zip
	@echo "🛠️ Installing..."
	@unzip -qq -o chrome.zip -d /tmp/
	@unzip -qq -o chromedriver.zip -d /tmp/
	@mkdir -p ~/bin
	@rm -rf ~/Applications/Google\ Chrome\ for\ Testing.app
	@rm -f ~/bin/chromedriver
	@mv /tmp/chrome-mac-arm64/Google\ Chrome\ for\ Testing.app ~/Applications/
	@mv /tmp/chromedriver-mac-arm64/chromedriver ~/bin/
	@rm chrome.zip chromedriver.zip
	@rm -rf /tmp/chrome-mac-arm64 /tmp/chromedriver-mac-arm64
	@chmod +x ~/bin/chromedriver
	@sed -i '' 's/^LOCAL_CI=.*/LOCAL_CI=true/' .env.test
	@sed -i '' 's|^CHROME_BINARY_PATH=.*|CHROME_BINARY_PATH="~/Applications/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"|' .env.test
	@sed -i '' 's|^CHROME_DRIVER_PATH=.*|CHROME_DRIVER_PATH="~/bin/chromedriver"|' .env.test
	@echo "🟢 Chrome version : $$(~/Applications/Google\ Chrome\ for\ Testing.app/Contents/MacOS/Google\ Chrome\ for\ Testing --version)"
	@echo "-> Binary location :	~/Applications/Google\ Chrome\ for\ Testing.app/Contents/MacOS/Google\ Chrome\ for\ Testing"
	@echo "🟢 Chromedriver version : $$(~/bin/chromedriver --version)"
	@echo "-> Binary location :	~/bin/chromedriver"
else ifeq ($(UNAME_S),Linux)
  # A tester
	@echo "TODO ---> 🛠️ Installing chromedriver version $(version) for Linux"
	# wget --no-verbose -O /tmp/chrome.deb "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_$(version)-1_amd64.deb"
	# curl -fsSL https://storage.googleapis.com/chrome-for-testing-public/$(version)/linux64/chromedriver-linux64.zip -o chromedriver.zip
	# sudo apt remove -y google-chrome-stable
	# sudo apt install -y /tmp/chrome.deb
	# rm /tmp/chrome.deb
	# unzip chromedriver.zip
	# sudo mv chromedriver-linux64/chromedriver /usr/bin/chromedriver
	# rm chromedriver.zip
	# rm -fr chromedriver-linux64
	# sudo chmod +x /usr/bin/chromedriver
	# chromedriver -v
	# google-chrome --version
endif

# Setup the Vite configuration for the local environment, desactivate the docker configuration.
setup-vite:
	@cp config/vite.json.local config/vite.json

###############################################
##### Local tasks #############################
###############################################

## lauch all the local services needed to run the app
# and starts all components using tmuxinator.
# example:
#   make up            # Sets up the environment and start all components with tmuxinator
#
up:
	@$(MAKE) setup-vite; \
	tmuxinator start demat-social; \

## Stop all (or per service with arg proc=service_name) the local services needed to run the app
# If no specific process is targeted, it stops all environments managed by tmuxinator.
# Usage: make down proc=<component_name>
# Example:
#
#		make down proc=rails - This will send a signal to gracefully stop the Rails server.
#
# If no proc is specified, all components will be stopped.
#
down:
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

## Resets the development database to its initial state and sets up the necessary database structures.
# This command drops the existing database, recreates it, and then populates it according to the defined schema and seeds.
# Additionally, it prepares the database for parallel test execution.
# Usage:
#
#		make dbreset
#
dbreset:
	bundle exec rails db:reset
	bundle exec rake parallel:create

## Controls the local database service to either start or stop.
# This command toggles the state of the PostgreSQL service using predefined system commands.
# Usage:
#
#		make dblocal c=START to start the database, and make dblocal c=STOP to stop the database.
#
dblocal:
	@$(DB_SERVICE_CMD_$(c))

## Loads a production database dump into the development environment.
# it is an other database than the normal development database
# Useful for loading real data into an second local database to test against production-like data.
# It will run the data migration defined in the bin/migrate-data.sh script.
# The location of the dump file is in a folder named `dumps` at the same level as the project.
# Usage:
#
# 	make dbload-prod
#
dbload-prod:
	@cp ../dumps/$(postgres_dump) ./
	@psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS tps_development_dump_prod;"
	@psql -U postgres -d postgres -c "CREATE DATABASE tps_development_dump_prod;"
	@psql -U $(postgres_role) -d tps_development_dump_prod -f $(postgres_dump)
	@rm ./$(postgres_dump)
	@if grep -q 'tps_development_dump_prod' config/database.yml; then \
		echo "🔧 tps_development_dump_prod already configured"; \
	else \
		$(MAKE) use-dbprod; \
	fi
	# bin/migrate-data.sh

## Switches the connection string in the .env.development to use the production dump database.
# Use this after loading a production dump to point your application to the right database.
# Usage: make use-dbprod
# Example:
#
#		make use-dbprod - Modifies the .env file to use the development database loaded from the production dump.
#
use-dbprod:
	@sed -i '' 's/^\(DB_DATABASE=\).*/\1tps_development_dump_prod/' .env.development
	@echo "\n 💾 Using the production dump database"

## Sets the database connection in the .env.development back to the default development database.
# Usage: make use-dbdev
# Example:
#
# 	make use-dbdev - Resets the development database environment variable.
#
use-dbdev:
	@sed -i '' 's/^\(DB_DATABASE=\).*/\1tps_development/' .env.development
	@echo "\n 💾 Using the development database"

###############################################
##### Test suite ##############################
###############################################

# Description:
# Cette target "rspec-whatsnew" permet d'identifier les fichiers de tests RSpec qui n'ont pas encore été mesurés ou enregistrés dans le fichier de log
# `config/parallel_runtime_rspec_test.log`. Elle est utile pour détecter rapidement les nouveaux tests ajoutés au projet qui nécessitent d'être exécutés et mesurés.
#
# Arguments:
# Cette target ne prend aucun argument. Elle utilise deux fichiers de log :
# 1. `config/parallel_runtime_rspec_test.log` : Contient les fichiers de tests déjà mesurés.
# 2. `config/parallel_runtime_rspec_test_new.log` : Non utilisé dans cette target mais pourrait être pertinent pour une utilisation future.
#
# Étapes :
# 1. Récupère la liste de tous les fichiers de tests RSpec présents dans le dossier `./spec`.
# 2. Récupère la liste des fichiers de tests déjà mesurés, selon le fichier de log `config/parallel_runtime_rspec_test.log`.
# 3. Trie ces deux listes et stocke les résultats dans des fichiers temporaires.
# 4. Compare les deux listes pour identifier les fichiers de tests qui ne sont pas encore mesurés.
# 5. Affiche la liste des fichiers de tests non mesurés.
#
# Exemple :
# Pour exécuter cette target, il suffit de taper la commande suivante dans votre terminal :
# ```
# make rspec-whatsnew
# ```
# Cela affichera les fichiers de tests RSpec qui ne sont pas encore mesurés, vous permettant ainsi de les identifier et de prendre les mesures nécessaires.
logfile := config/parallel_runtime_rspec_test.log
new_test_log := config/parallel_runtime_rspec_test_new.log
rspec-whatsnew:
	@echo "\n 🔎 Vérification des nouveaux fichiers de tests...\n"
	@all_specs=$$(find ./spec -type f -name "*_spec.rb" | sed 's/^.\///'); \
	measured_specs=$$(cut -d: -f1 $(logfile)); \
	echo "$$all_specs" | sort > all_specs.tmp; \
	echo "$$measured_specs" | sort > measured_specs.tmp; \
	not_measured_specs=$$(comm -23 all_specs.tmp measured_specs.tmp); \
	rm all_specs.tmp measured_specs.tmp; \
	echo "\n 👇 Fichiers de tests non mesurés:\n"; \
	for spec in $$not_measured_specs; do \
		echo "$$spec"; \
	done


# rspec-mesurenewtests:
# Cette cible recherche et exécute des tests RSpec qui ne sont pas encore mesurés pour leur temps d'exécution,
# puis enregistre les résultats dans un nouveau fichier de log.
#
# Arguments attendus :
# - nb_workers : (optionnel) le nombre de processus parallèles à utiliser pour l'exécution des tests.
#
# Étapes :
# 1. Recherche tous les fichiers de tests (spec) existants dans le répertoire `./spec`.
# 2. Identifie les fichiers de tests qui n'ont pas encore été mesurés en les comparant avec le log existant (`$(logfile)`).
# 3. Affiche la liste des nouveaux fichiers de tests non mesurés.
# 4. Divise les fichiers de tests non mesurés en quatre parties à exécuter en parallèle.
# 5. Exécute les tests non mesurés en utilisant `parallel_rspec` et enregistre les résultats de chaque partie dans des fichiers de log temporaires.
# 6. Combine les résultats dans un nouveau fichier de log (`config/parallel_runtime_new.log`) et supprime les fichiers temporaires.
# 7. il faudra copier les valeurs de ce fichier (parallel_runtime_new) dans le fichier de log principal : `config/parallel_runtime_rspec_test.log`
#
# Exemple d'utilisation :
# make rspec-mesurenewtests nb_workers=4
#
# Ce qui va lancer les tests RSpec en utilisant 4 processus parallèles et enregistrer les temps d'exécution des nouveaux tests.
logfile := config/parallel_runtime_rspec_test.log
new_test_log := config/parallel_runtime_rspec_test_new.log
rspec-mesurenewtests:
	@echo "\n 🔎 Recherche des nouveaux fichiers de tests...\n"
	@all_specs=$$(find ./spec -type f -name "*_spec.rb" | sed 's/^.\///'); \
	measured_specs=$$(cut -d: -f1 $(logfile)); \
	echo "$$all_specs" | sort > all_specs.tmp; \
	echo "$$measured_specs" | sort > measured_specs.tmp; \
	not_measured_specs=$$(comm -23 all_specs.tmp measured_specs.tmp); \
	rm all_specs.tmp measured_specs.tmp; \
	if [ -z "$$not_measured_specs" ]; then \
		echo "Aucun nouveau fichier de test trouvé."; \
	else \
		echo "\n 👇 Fichiers de tests non mesurés:\n"; \
		for spec in $$not_measured_specs; do \
			echo "$$spec"; \
		done; \
		total_specs=$$(echo "$$not_measured_specs" | wc -l); \
		specs_per_part=$$(( (total_specs + 3) / 4 )); \
		part1=$$(echo "$$not_measured_specs" | sed -n "1,$${specs_per_part}p" | tr '\n' '|'); \
		part2=$$(echo "$$not_measured_specs" | sed -n "$$((specs_per_part + 1)),$$((2 * specs_per_part))p" | tr '\n' '|'); \
		part3=$$(echo "$$not_measured_specs" | sed -n "$$((2 * specs_per_part + 1)),$$((3 * specs_per_part))p" | tr '\n' '|'); \
		part4=$$(echo "$$not_measured_specs" | sed -n "$$((3 * specs_per_part + 1)),$$((4 * specs_per_part))p" | tr '\n' '|'); \
		part1=$$(echo "$$part1" | sed 's/|$$//'); \
		part2=$$(echo "$$part2" | sed 's/|$$//'); \
		part3=$$(echo "$$part3" | sed 's/|$$//'); \
		part4=$$(echo "$$part4" | sed 's/|$$//'); \
		echo "\n 🚀 Lancement des tests sur les nouveaux fichiers de tests...\n"; \
		if [ -n "$$part1" ]; then \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --pattern "$$part1" --test-options "--format ParallelTests::RSpec::RuntimeLogger --out $(new_test_log).part1"; \
		fi; \
		if [ -n "$$part2" ]; then \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --pattern "$$part2" --test-options "--format ParallelTests::RSpec::RuntimeLogger --out $(new_test_log).part2"; \
		fi; \
		if [ -n "$$part3" ]; then \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --pattern "$$part3" --test-options "--format ParallelTests::RSpec::RuntimeLogger --out $(new_test_log).part3"; \
		fi; \
		if [ -n "$$part4" ]; then \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --pattern "$$part4" --test-options "--format ParallelTests::RSpec::RuntimeLogger --out $(new_test_log).part4"; \
		fi; \
		for log_file in $(new_test_log).part1 $(new_test_log).part2 $(new_test_log).part3 $(new_test_log).part4; do \
			if [ -f "$$log_file" ]; then \
				grep '^spec' "$$log_file" >> config/parallel_runtime_new.log; \
			fi; \
		done; \
		rm -f "$(new_test_log).part1" "$(new_test_log).part2" "$(new_test_log).part3" "$(new_test_log).part4"; \
		cat $(new_test_log) >> $(logfile); \
		rm -f $(new_test_log); \
		echo "\n 🟢 Tests terminés et résultats enregistrés dans $(logfile)"; \
	fi



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

## Executes unit tests using the parallel_rspec tool to speed up the test process.
# ⚠️ This is made to avoid an unresolved memory leaks issue ⚠️
# This command categorizes and runs unit tests across different specs in parallel based on previous runtime logs, optimizing the testing process on successive runs.
# It first checks if a runtime log exists to follow an optimized test executing order; if not, it creates a new runtime log.
#
# Usage: make rspec-unit nb_workers=<number_of_workers> [only_tests_number=<test_number>]
#
# Parameters:
#   nb_workers: Number of parallel workers to use
#   only_tests_number: Optional. Specifies which test set to run in the optimized launch (1-20)
#
# Examples:
# 	make rspec-unit nb_workers=4
# 	make rspec-unit nb_workers=5 only_tests_number=1
# 	make rspec-unit nb_workers=5 only_tests_number=10
#
rspec-unit:
	@if [ ! -e ./config/parallel_runtime_rspec_unit_test.log ]; then \
		echo '\n✨ First launch - Running all unit tests'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --exclude-pattern 'spec/system/.*_spec.rb' --test-options "--format ParallelTests::RSpec::RuntimeLogger --out ./config/parallel_runtime_rspec_unit_test.log"; \
		echo '\n🟢 Unit test suite completed'; \
	else \
		echo '\n🚀 Optimized launch with $(nb_workers) workers'; \
		if [ "$(only_tests_number)" = "1" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 1: spec/(components|graphql|helpers|middlewares|mailers|policies|serializers)/.*_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(components|graphql|helpers|middlewares|mailers|policies|serializers)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "2" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 2: spec/services/dossier_projection_service_spec.rb|spec/services/pieces_justificatives_service_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/services/dossier_projection_service_spec.rb|spec/services/pieces_justificatives_service_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "3" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 3: spec/(lib)/.*_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(lib)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "4" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 4: spec/controllers/administrateurs/.*_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/controllers/administrateurs/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "5" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 5: spec/jobs/batch_operation_process_one_job_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/jobs/batch_operation_process_one_job_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "6" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 6: spec/jobs/active_storage/base_job_spec.rb|spec/jobs/cron/discarded_dossiers_deletion_job_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/jobs/active_storage/base_job_spec.rb|spec/jobs/cron/discarded_dossiers_deletion_job_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "7" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 7: spec/(jobs)/.*_spec.rb (excluding specific job specs)"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(jobs)/.*_spec.rb' --exclude-pattern 'spec/jobs/batch_operation_process_one_job_spec.rb|spec/jobs/active_storage/base_job_spec.rb|spec/jobs/cron/discarded_dossiers_deletion_job_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "8" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 8: spec/services/dossier_search_service_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/services/dossier_search_service_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "9" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 9: spec/controllers/managers/.*_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/controllers/managers/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "10" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 10: spec/controllers/champs/.*_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/controllers/champs/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "11" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 11: spec/controllers/.*_spec.rb (excluding specific controller specs)"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/controllers/.*_spec.rb' --exclude-pattern 'spec/controllers/(users|administrateurs|managers|champs|instructeurs|api)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "12" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 12: spec/services/procedure_export_service_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/services/procedure_export_service_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "13" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 13: spec/(models)/.*_spec.rb (excluding specific model specs)"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(models)/.*_spec.rb' --exclude-pattern 'spec/models/instructeur_spec.rb|spec/models/dossier_spec.rb|spec/models/procedure_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "14" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 14: spec/(views)/.*_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(views)/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "15" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 15: spec/controllers/instructeurs/.*_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/controllers/instructeurs/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "16" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 16: spec/(services)/.*_spec.rb (excluding specific service specs)"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/(services)/.*_spec.rb' --exclude-pattern 'spec/services/dossier_projection_service_spec.rb|spec/services/pieces_justificatives_service_spec.rb|spec/services/procedure_export_service_spec.rb|spec/services/dossier_search_service_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "17" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 17: spec/controllers/api/.*_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/controllers/api/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "18" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 18: spec/controllers/users/.*_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/controllers/users/.*_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "19" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 19: spec/models/instructeur_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/models/instructeur_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "20" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 20: spec/models/dossier_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/models/dossier_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "21" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 21: spec/models/procedure_spec.rb"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/models/procedure_spec.rb' --test-options "--format progress" --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
		fi; \
		echo '\n🟢 Unit test suite completed'; \
	fi

## Executes system tests using the parallel_rspec tool, effectively speeding up testing by running multiple tests in parallel.
# ⚠️ This is made to avoid an unresolved memory leaks issue ⚠️
# This command initially cleans up Capybara temporary files to prevent tests from being affected by stale data.
# Depending on whether a runtime log exists, it either conducts a full refresh of all system tests or runs them in an optimized sequence based on previous test durations to minimize total run time.
# Usage: make rspec-system nb_workers=<number_of_workers> [only_tests_number=<test_number>]
#
# Parameters:
#   nb_workers: Number of parallel workers to use
#   only_tests_number: Optional. Specifies which test to run in the optimized launch (1, 2, 3, or 4)
#
# Examples:
# 	make rspec-system nb_workers=4
# 	make rspec-system nb_workers=5 only_tests_number=1
# 	make rspec-system nb_workers=5 only_tests_number=3
#
rspec-system:
	@rm -rf tmp/capybara/*
	@if [ ! -e ./config/parallel_runtime_rspec_test.log ]; then \
		echo '\n✨ First launch - Running all tests'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec spec/system/**/*_spec.rb --test-options "--format ParallelTests::RSpec::RuntimeLogger --out ./config/parallel_runtime_rspec_test.log"; \
		echo '\n🟢 System test suite completed'; \
	else \
		echo '\n🚀 Optimized launch with $(nb_workers) workers'; \
		if [ "$(only_tests_number)" = "1" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 1: spec/system/(accessibilite|integrateurs)/.*_spec.rb" \n; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(accessibilite|integrateurs)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "2" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 2: spec/system/(instructeurs|experts|france_connect|routing|routing|misc|api_particulier)/.*_spec.rb \n"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(instructeurs|experts|france_connect|routing|routing|misc|api_particulier)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "3" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 3: spec/system/(users)/.*_spec.rb \n"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(users)/.*_spec.rb' --exclude-pattern 'spec/system/users/brouillon_spec.rb' --runtime-log ./config/parallel_runtime_rspec_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "4" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 4: spec/system/(administrateurs)/.*_spec.rb \n"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/(administrateurs)/.*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_test.log; \
		fi; \
		if [ "$(only_tests_number)" = "5" ] || [ -z "$(only_tests_number)" ]; then \
			echo "\n🏁 Running test set 5: spec/system/users/brouillon_spec.rb \n"; \
			bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --pattern 'spec/system/users/brouillon_spec.rb' --runtime-log ./config/parallel_runtime_rspec_test.log; \
		fi; \
	fi

rspec-system-visual: ## Executes a single system test file in a visual mode, allowing browsers to be visible during the test which aids in debugging.
# This command is useful when detailed observation of the UI flow is needed or for demonstration purposes.
# exemple :
#		make rseq-system-visual file=<file_path> slow=true
#
	MAKE_IT_SLOW=$(slow) NO_HEADLESS=1 bundle exec rspec $(file)

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
##### Variable environment ####################
###############################################

# env_find_duplicates:
# This target searches for duplicate variable declarations in a given .env file,
# showing the line numbers where each duplicate is found.
# Usage:
#   make env_find_duplicates env_file=path/to/your/.env.file
#
# If env_file is not provided, it will default to .env.development
#
env_find_duplicates:
	@env_file=$${env_file:-.env.development}; \
	if [ ! -f $$env_file ]; then \
		echo "❌ Error: File $$env_file does not exist."; \
		exit 1; \
	fi; \
	echo "🔍 Searching for duplicates in $$env_file..."; \
	duplicates=$$(grep -v '^#' $$env_file | grep '=' | cut -d '=' -f 1 | sort | uniq -d); \
	if [ -z "$$duplicates" ]; then \
		echo "✅ No duplicates found in $$env_file."; \
	else \
		echo "⚠️  Duplicate variables found:"; \
		for var in $$duplicates; do \
			echo "\n👉 $$var:"; \
			grep -n "^$$var=" $$env_file | while IFS=':' read -r line_num content; do \
				echo "  Line $$line_num: $$content"; \
			done; \
		done; \
	fi

env_compare:
	@main_file=$${main_file:-.env.example}; \
	other_file=$${other_file:-.env.development}; \
	write_temp=$${write_temp:-false}; \
	silent=$${silent:-false}; \
	if [ ! -f $$main_file ]; then \
		echo "❌ Error: File $$main_file does not exist."; \
		exit 1; \
	fi; \
	if [ ! -f $$other_file ]; then \
		echo "❌ Error: File $$other_file does not exist."; \
		exit 1; \
	fi; \
	if [ "$$write_temp" = "true" ]; then \
		if [ "$$silent" != "true" ]; then \
			echo "\n🗑️ Remove Temp files"; \
		fi; \
		rm -f env_compare_only_in_main_file.tmp; \
		rm -f env_compare_only_in_other_file.tmp; \
		rm -f env_compare_different_values.tmp; \
		rm -f env_compare_same_values.tmp; \
	fi; \
	if [ "$$silent" != "true" ]; then \
		echo "\n#######################################"; \
		echo "##### 🔍 Comparing $$main_file and $$other_file"; \
		echo "#######################################\n"; \
	fi; \
	\
	extract_var() { \
		echo "$$1" | sed -E 's/^[[:space:]]*#?[[:space:]]*//' | cut -d'=' -f1 | tr -d ' '; \
	}; \
	extract_value() { \
		echo "$$1" | sed -E 's/^[[:space:]]*#?[[:space:]]*//' | cut -d'=' -f2- | sed -E 's/^[[:space:]]*"?//;s/"?[[:space:]]*$$//;s/[[:space:]]*#.*$$//'; \
	}; \
	is_commented() { \
		echo "$$1" | grep -q '^[[:space:]]*#'; \
	}; \
	\
	if [ "$$silent" != "true" ]; then \
		echo "------- 📗 Variables only in $$main_file --------\n"; \
	fi; \
	if [ "$$write_temp" = "true" ]; then \
		> env_compare_only_in_main_file.tmp; \
	fi; \
	grep '=' "$$main_file" | while read -r line1; do \
		var=$$(extract_var "$$line1"); \
		if ! grep -q "^[[:space:]]*#*[[:space:]]*$$var[[:space:]]*=" "$$other_file"; then \
			value=$$(extract_value "$$line1"); \
			if [ "$$silent" != "true" ]; then \
				printf "\033[34m%s\033[0m=%s\n" "$$var" "$$value"; \
			fi; \
			if [ "$$write_temp" = "true" ]; then \
				echo "$$var=$$value" >> env_compare_only_in_main_file.tmp; \
			fi; \
		fi; \
	done; \
	if [ "$$silent" != "true" ]; then \
		echo; \
	fi; \
	\
	if [ "$$silent" != "true" ]; then \
		echo "------- 📘 Variables only in $$other_file --------\n"; \
	fi; \
	if [ "$$write_temp" = "true" ]; then \
		> env_compare_only_in_other_file.tmp; \
	fi; \
	grep '=' "$$other_file" | while read -r line2; do \
		var=$$(extract_var "$$line2"); \
		if ! grep -q "^[[:space:]]*#*[[:space:]]*$$var[[:space:]]*=" "$$main_file"; then \
			value=$$(extract_value "$$line2"); \
			if [ "$$silent" != "true" ]; then \
				printf "\033[34m%s\033[0m=%s\n" "$$var" "$$value"; \
			fi; \
			if [ "$$write_temp" = "true" ]; then \
				echo "$$var=$$value" >> env_compare_only_in_other_file.tmp; \
			fi; \
		fi; \
	done; \
	if [ "$$silent" != "true" ]; then \
		echo; \
	fi; \
	\
	if [ "$$silent" != "true" ]; then \
		echo "------- 📙 Common variables with different values or comment status --------\n"; \
	fi; \
	if [ "$$write_temp" = "true" ]; then \
		> env_compare_different_values.tmp; \
	fi; \
	grep '=' "$$main_file" | while read -r line1; do \
		var=$$(extract_var "$$line1"); \
		value1=$$(extract_value "$$line1"); \
		line2=$$(grep "^[[:space:]]*#*[[:space:]]*$$var[[:space:]]*=" "$$other_file"); \
		if [ -n "$$line2" ]; then \
			value2=$$(extract_value "$$line2"); \
			is_commented1=$$(is_commented "$$line1" && echo true || echo false); \
			is_commented2=$$(is_commented "$$line2" && echo true || echo false); \
			if [ "$$value1" != "$$value2" ] || [ "$$is_commented1" != "$$is_commented2" ]; then \
				if [ "$$silent" != "true" ]; then \
					printf "\033[34m%s\033[0m:\n" "$$var"; \
					printf "  %s: %s %s\n" "$$main_file" "$$value1" "$$([ "$$is_commented1" = true ] && echo '(commented)' || echo '')"; \
					printf "  %s: %s %s\n\n" "$$other_file" "$$value2" "$$([ "$$is_commented2" = true ] && echo '(commented)' || echo '')"; \
				fi; \
				if [ "$$write_temp" = "true" ]; then \
					echo "$$main_file:$$var=$$value1" >> env_compare_different_values.tmp; \
					echo "$$other_file:$$var=$$value2" >> env_compare_different_values.tmp; \
				fi; \
			fi; \
		fi; \
	done; \
	\
	if [ "$$silent" != "true" ]; then \
		echo "------- 📗📘 Common variables with the same value and comment status --------\n"; \
	fi; \
	if [ "$$write_temp" = "true" ]; then \
		> env_compare_same_values.tmp; \
	fi; \
	grep '=' "$$main_file" | while read -r line1; do \
		var=$$(extract_var "$$line1"); \
		value1=$$(extract_value "$$line1"); \
		line2=$$(grep "^[[:space:]]*#*[[:space:]]*$$var[[:space:]]*=" "$$other_file"); \
		if [ -n "$$line2" ]; then \
			value2=$$(extract_value "$$line2"); \
			is_commented1=$$(is_commented "$$line1" && echo true || echo false); \
			is_commented2=$$(is_commented "$$line2" && echo true || echo false); \
			if [ "$$value1" = "$$value2" ] && [ "$$is_commented1" = "$$is_commented2" ]; then \
				if [ "$$silent" != "true" ]; then \
					printf "\033[34m%s\033[0m=%s %s\n" "$$var" "$$value1" "$$([ "$$is_commented1" = true ] && echo '(commented)' || echo '')"; \
				fi; \
				if [ "$$write_temp" = "true" ]; then \
					echo "$$var=$$value1" >> env_compare_same_values.tmp; \
				fi; \
			fi; \
		fi; \
	done; \
	\
	if [ "$$write_temp" = "true" ] && [ "$$silent" != "true" ]; then \
		echo "\n📁 Temp files have been created:"; \
		echo "  - env_compare_only_in_main_file.tmp"; \
		echo "  - env_compare_only_in_other_file.tmp"; \
		echo "  - env_compare_different_values.tmp"; \
		echo "  - env_compare_same_values.tmp"; \
	fi;

# env_merge: Compares two .env files and offers various merge strategies.
#
# This target uses env_compare to analyze the differences between two .env files,
# then presents the user with four merge strategies:
# 1. Hard update: Replaces all variables with main_file, updates differing values
#    from other_file, adds new variables from other_file, and removes variables
#    only present in main_file.
# 2. Additive update: Keeps main_file variables, updates differing values from
#    other_file, and adds new variables from other_file.
# 3. Soft additive update: Keeps main_file variables and only adds new variables
#    from other_file.
# 4. Existing update: Keeps main_file variables and only updates differing values
#    from other_file.
#
# The result of the chosen merge strategy is saved in a new file: .env.merge_result
#
# Usage:
#   make env_merge main_file=path/to/main/.env.file other_file=path/to/other/.env.file
#
# Example:
#   make env_merge main_file=.env.example other_file=.env.development
#
# If main_file or other_file is not provided, it will use default values:
#   main_file defaults to .env.example
#   other_file defaults to .env.development
env_merge:
	@main_file=$${main_file:-.env.example}; \
	other_file=$${other_file:-.env.development}; \
	\
	$(MAKE) env_compare main_file=$$main_file other_file=$$other_file write_temp=true silent=true; \
	\
	echo "\n#######################################"; \
	echo "##### 🔍 Comparing $$main_file and $$other_file"; \
	echo "#######################################\n"; \
	\
	echo "🔀 Choose a merge strategy:"; \
	echo "1) Hard update: Replace all variables with main_file, update differing values from other_file, add new variables from other_file, remove variables only in main_file."; \
	echo "2) Additive update: Keep main_file variables, update differing values from other_file, add new variables from other_file."; \
	echo "3) Soft additive update: Keep main_file variables, only add new variables from other_file."; \
	echo "4) Existing update: Keep main_file variables, only update differing values from other_file."; \
	echo "5) Cancel merge"; \
	read -p "Enter your choice (1-5): " choice; \
	\
	if [ $$choice -eq 1 ]; then \
    echo "\n🔨 You've chosen Hard update."; \
    echo "- create a new .env.merge_result file with all variables from $$main_file,"; \
    echo "- update values from $$other_file where they differ,"; \
    echo "- add new variables from $$other_file,"; \
    echo "- remove variables only present in $$main_file."; \
    \
    read -p "Do you want to proceed with this merge? (y/n): " confirm; \
    if [ "$$confirm" != "y" ]; then \
        echo "\n❌ Merge cancelled."; \
        exit 0; \
    fi; \
    \
    echo "\n🚀 Proceeding with the Hard update merge..."; \
    \
    grep -v '^#' $$main_file > .env.merge_result; \
    \
    while IFS= read -r line; do \
        if [[ $$line == $$other_file:* ]]; then \
            var=$${line#$$other_file:}; \
            var_name=$${var%%=*}; \
            var_value=$${var#*=}; \
            sed -i '' -e "s|^$$var_name=.*|$$var_name=$$var_value|" .env.merge_result; \
        fi; \
    done < env_compare_different_values.tmp; \
    \
    cat env_compare_only_in_other_file.tmp >> .env.merge_result; \
    \
    while read -r line; do \
        sed -i '' -e "/^$${line%%=*}=/d" .env.merge_result; \
    done < env_compare_only_in_main_file.tmp; \
    \
    echo "\n✅ Hard update complete. Result saved in .env.merge_result"; \
	fi; \
	\
	if [ $$choice -eq 2 ]; then \
    echo "\n➕ You've chosen Additive update."; \
    echo "- create a new .env.merge_result file with all variables from $$main_file,"; \
    echo "- update values from $$other_file where they differ,"; \
    echo "- add new variables from $$other_file."; \
    \
    read -p "Do you want to proceed with this merge? (y/n): " confirm; \
    if [ "$$confirm" != "y" ]; then \
        echo "\n❌ Merge cancelled."; \
        exit 0; \
    fi; \
    \
    echo "\n🚀 Proceeding with the Additive update merge..."; \
    \
    grep -v '^#' $$main_file > .env.merge_result; \
    \
    while IFS= read -r line; do \
        if [[ $$line == $$other_file:* ]]; then \
            var=$${line#$$other_file:}; \
            var_name=$${var%%=*}; \
            var_value=$${var#*=}; \
            sed -i '' -e "s|^$$var_name=.*|$$var_name=$$var_value|" .env.merge_result; \
        fi; \
    done < env_compare_different_values.tmp; \
    \
    while read -r line; do \
        if ! grep -q "^$${line%%=*}=" .env.merge_result; then \
            echo "$$line" >> .env.merge_result; \
        fi; \
    done < env_compare_only_in_other_file.tmp; \
    \
    echo "\n✅ Additive update complete. Result saved in .env.merge_result"; \
	fi; \
	\
	if [ $$choice -eq 3 ]; then \
    echo "\n🌱 You've chosen Soft additive update."; \
    echo "- create a new .env.merge_result file with all variables from $$main_file,"; \
    echo "- only add new variables from $$other_file."; \
    \
    read -p "Do you want to proceed with this merge? (y/n): " confirm; \
    if [ "$$confirm" != "y" ]; then \
        echo "\n❌ Merge cancelled."; \
        exit 0; \
    fi; \
    \
    echo "\n🚀 Proceeding with the Soft additive update merge..."; \
    \
    grep -v '^#' $$main_file > .env.merge_result; \
    \
    while read -r line; do \
        if ! grep -q "^$${line%%=*}=" .env.merge_result; then \
            echo "$$line" >> .env.merge_result; \
        fi; \
    done < env_compare_only_in_other_file.tmp; \
    \
    echo "\n✅ Soft additive update complete. Result saved in .env.merge_result"; \
	fi; \
	\
	if [ $$choice -eq 4 ]; then \
    echo "\n🔄 You've chosen Existing update."; \
    echo "- create a new .env.merge_result file with all variables from $$main_file,"; \
    echo "- only update values of existing variables where they differ in $$other_file."; \
    \
    read -p "Do you want to proceed with this merge? (y/n): " confirm; \
    if [ "$$confirm" != "y" ]; then \
        echo "\n❌ Merge cancelled."; \
        exit 0; \
    fi; \
    \
    echo "\n🚀 Proceeding with the Existing update merge..."; \
    \
    grep -v '^#' $$main_file > .env.merge_result; \
    \
    while IFS= read -r line; do \
        if [[ $$line == $$other_file:* ]]; then \
            var=$${line#$$other_file:}; \
            var_name=$${var%%=*}; \
            var_value=$${var#*=}; \
            sed -i '' -e "s|^$$var_name=.*|$$var_name=$$var_value|" .env.merge_result; \
        fi; \
    done < env_compare_different_values.tmp; \
    \
    echo "\n✅ Existing update complete. Result saved in .env.merge_result\n"; \
	fi;
	@cat .env.merge_result
	@rm env_compare_only_in_main_file.tmp env_compare_only_in_other_file.tmp env_compare_different_values.tmp env_compare_same_values.tmp

env_fork_diff:
	@echo "🔄 Syncing environment variables between demarches-simplifiees and your fork..."

	@main_file="config/env.example"; \
	other_file="config/env.example.optional"; \
	$(MAKE) env_compare2 main_file=$$main_file other_file=$$other_file write_temp=true silent=true; \
	grep -v '^#' $$main_file > demat_env.tmp; \
	\
	while read -r line; do \
			if ! grep -q "^$${line%%=*}=" demat_env.tmp; then \
					echo "$$line" >> demat_env.tmp; \
			fi; \
	done < env_compare_only_in_other_file.tmp; \
	rm -f env_compare_only_in_main_file.tmp env_compare_only_in_other_file.tmp env_compare_different_values.tmp env_compare_same_values.tmp;

	@main_file=".env.example"; \
	other_file=".env.demarchesocial.example"; \
	$(MAKE) env_compare main_file=$$main_file other_file=$$other_file write_temp=true silent=true; \
	grep -v '^#' $$main_file > dematsocial_env.tmp; \
	\
	while read -r line; do \
			if ! grep -q "^$${line%%=*}=" dematsocial_env.tmp; then \
					echo "$$line" >> dematsocial_env.tmp; \
			fi; \
	done < env_compare_only_in_other_file.tmp; \
	\
	$(MAKE) env_compare main_file=demat_env.tmp other_file=dematsocial_env.tmp; \
	rm -f demat_env.tmp dematsocial_env.tmp env_compare_only_in_main_file.tmp env_compare_only_in_other_file.tmp env_compare_different_values.tmp env_compare_same_values.tmp;

# demat_simplifie_mandatory_env := config/env.example
# demat_simplifie_optional_env := config/env.example.optional
# demat_social_shared_env := .env.example
# demat_social_custom_env := .env.demarchesocial.example

# env_create_dev:
# This Makefile target creates a .env.development file by merging the contents of
# demat_social_shared_env and demat_social_custom_env.
#
# Usage:
#   make create_env_dev
#
env_create_dev:
	@cat $(demat_social_shared_env) $(demat_social_custom_env) > .env.development
	@echo "🌏 .env.development file has been created by merging $(demat_social_shared_env) and $(demat_social_custom_env)."

switch_to: ## Switch to a specified version branch, setup the environment and database
# Usage: make switch_to_version version=<branch_name>
# This command will stash the current changes, switch to the specified version branch,
# install necessary gems and JS libraries, create .env.development if needed, and setup the database.
# Example:
#
#   make switch_to_version version=v1.0.0
#
	@if [ -z "$(version)" ]; then \
		echo "🔴 Please provide a version: make switch_to_version version=<branch_name>"; \
		exit 1; \
	fi; \
	current_branch=$$(git rev-parse --abbrev-ref HEAD); \
	stash_message="Switch stash of branch $$current_branch"; \
	$(MAKE) down; \
	echo "⬇️ 💾 $$stash_message"; \
	git stash push -m "$$stash_message"; \
	git checkout $(version); \
	current_branch=$$(git rev-parse --abbrev-ref HEAD); \
	stash_message="Switch stash of branch $$current_branch"; \
	echo "⬆️ 💾 $$stash_message"; \
	if git stash list | grep -q "$$stash_message"; then \
		git stash pop "$$(git stash list | grep "$$stash_message" | head -n 1 | awk -F: '{print $$1}')"; \
	fi; \
	bundle install; \
	yarn install; \
	sed -i.bak -e "s/^DEMARCHE_SOCIALE_VERSION=.*/DEMARCHE_SOCIALE_VERSION=$$version/" .env.demarchesocial.example &&	rm .env.demarchesocial.example.bak; \
	rm -f .env.development; \
	$(MAKE) env_create_dev; \
	$(MAKE) db-use version=$(version); \
	if ! psql -U postgres -lqt | cut -d \| -f 1 | grep -qw $$db_name; then \
		DB_DATABASE=$$db_name bundle exec rails db:setup; \
	fi; \
	$(MAKE) up


###############################################
##### database environment ####################
###############################################

PREFIX = tps_development_

db-list:
	@echo "Listing des bases de données avec le préfixe $(PREFIX):"
	@psql -d postgres -t -c "SELECT datname FROM pg_database WHERE datname LIKE '$(PREFIX)%';"

db-use:
	@version_underscore=$$(echo $(version) | sed 's/\./_/g'); \
	db_name="tps_development_$${version_underscore}"; \
	if psql -U postgres -lqt | cut -d \| -f 1 | grep -qw $$db_name; then \
		echo "🟢 Using the database $$db_name"; \
		sed -i.bak -e "s/^DB_DATABASE=.*/DB_DATABASE=$$db_name/" .env.development && rm .env.development.bak; \
	else \
		echo "🔴 The database $$db_name does not exist. Please create it first."; \
		exit 1; \
	fi


###############################################
##### scalingo environment ####################
###############################################

s-dbconsole:
	@if [ "$(app)" = "" ]; then \
		echo "🔴 Please provide the app name: make s-dbconsole app=<app_name>"; \
		exit 1; \
	fi; \
	scalingo --app $(app) psql-console

s-dblogs:
	@if [ "$(app)" = "" ]; then \
		echo "🔴 Please provide the app name: make s-dbconsole app=<app_name>"; \
		exit 1; \
	fi; \
	scalingo --app $(app) --addon postgresql logs -f

s-dburl:
	@if [ "$(app)" = "" ]; then \
		echo "🔴 Please provide the app name: make s-dbconsole app=<app_name>"; \
		exit 1; \
	fi; \
	scalingo --app $(app) env-get SCALINGO_POSTGRESQL_URL

s-logs:
	@if [ "$(app)" = "" ]; then \
		echo "🔴 Please provide the app name: make s-dbconsole app=<app_name>"; \
		exit 1; \
	fi; \
	scalingo --app $(app) logs -f

# Generate the scalingo.json file from the .env.development file
s-envtojsonfile:
	@jq -r '.env | to_entries[] | "\(.key)=\(.value.value // "")"' scalingo.json > scalingo_env.tmp
	@grep -v '^\s*#' .env.development | grep -v '^\s*$$' | grep '=' > env_development.tmp

	@# Compare values
	@awk -F= '{print $$1}' scalingo_env.tmp > scalingo_keys.tmp
	@awk -F= '{print $$1}' env_development.tmp > env_keys.tmp

	@# Inject missing variables
	@missing_vars=$$(grep -Fvxf scalingo_keys.tmp env_keys.tmp); \
	if [ -n "$$missing_vars" ]; then \
		echo "\n ✨ Injecting missing environment variables into scalingo.json..."; \
		echo "$$missing_vars" | while read var; do \
			value=$$(awk -F= -v var="$$var" '$$1 == var {val=substr($$0, index($$0,$$2)); if (length(val) == 0) {print ""} else {print val}}' env_development.tmp); \
			# Remove surrounding quotes for non-empty values \
			value=$$(echo "$$value" | sed 's/^"//; s/"$$//'); \
			jq --arg var "$$var" --arg value "$$value" '.env[$$var].value = $$value' scalingo.json > scalingo.json.tmp && mv scalingo.json.tmp scalingo.json; \
		done; \
	fi

	@rm scalingo_env.tmp env_development.tmp scalingo_keys.tmp env_keys.tmp

	@jq -r '.env | to_entries[] | "\(.key)=\(.value.value // "")"' scalingo.json > temp_env.txt
	@awk -F= '{ if (index($$2, $$1) != 0) print $$1 "=" ""; else print $$0; }' temp_env.txt > cleaned_env.txt
	@awk '!seen[$$0]++' cleaned_env.txt > unique_env.txt  # Remove duplicate lines
	@echo "{\"env\": {" > scalingo.json.tmp
	@awk -F= '{print "\"" $$1 "\": {\"value\": \"" $$2 "\"},"}' unique_env.txt >> scalingo.json.tmp
	@sed -i '' '$$ s/,$$//' scalingo.json.tmp  # Remove the last comma
	@echo "}}" >> scalingo.json.tmp
	@mv scalingo.json.tmp scalingo.json
	@rm temp_env.txt cleaned_env.txt unique_env.txt

	@echo "\n 🟢 Sync bewteed .env.development and scalingo.json completed.";


	@$(MAKE) s-showenvdif

# Compare the .env.development file with the scalingo.json file
s-showenvdif:
	@echo "\n 🔎 Checking for differences between .env.development and scalingo.json...";
	@jq -r '.env | to_entries[] | "\(.key)=\(.value.value)"' scalingo.json > scalingo_env.tmp
	@grep -v '^\s*#' .env.development | grep -v '^\s*$$' | grep '=' > env_development.tmp
	@awk -F= '{print $$1 "=" $$2}' scalingo_env.tmp > scalingo_key_value.tmp
	@awk -F= '{print $$1 "=" $$2}' env_development.tmp > env_key_value.tmp
	@awk -F= '{print $$1}' scalingo_key_value.tmp > scalingo_keys.tmp
	@awk -F= '{print $$1}' env_key_value.tmp > env_keys.tmp

	@extra_vars=$$(grep -Fvxf scalingo_keys.tmp env_keys.tmp); \
	if [ -z "$$extra_vars" ]; then \
		echo "\n 🟢 No missing variable in the scalingo.json file \n"; \
	else \
		echo "\n️ 🔴 Missing variable in the scalingo.json file \n"; \
		echo "$$extra_vars"; \
	fi

	@echo "\n 🔎 Conflict values : \n"
	@common_vars=$$(grep -Fxf env_keys.tmp scalingo_keys.tmp); \
	for var in $$common_vars; do \
		scalingo_value=$$(grep "^$$var=" scalingo_key_value.tmp | cut -d= -f2-); \
		env_value=$$(grep "^$$var=" env_key_value.tmp | cut -d= -f2-); \
		if [ -n "$$scalingo_value" ] && [ -n "$$env_value" ]; then \
			if [ "$$scalingo_value" != "$$env_value" ]; then \
				echo "$$var: different values"; \
				echo "  scalingo.json: $$scalingo_value"; \
				echo "  .env.development: $$env_value \n"; \
			fi \
		fi \
	done

	@rm scalingo_env.tmp env_development.tmp scalingo_key_value.tmp env_key_value.tmp scalingo_keys.tmp env_keys.tmp


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
	@$(MAKE) d-up

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
