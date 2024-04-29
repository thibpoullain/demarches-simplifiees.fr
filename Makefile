.PHONY: up connect restore_prod dump_dev load_dev rspec_unit rspec_system rspec_parallel_file rspec_system_visual

current_date := $(shell date '+%Y-%m-%d-%H:%M:%S')
postgres_dump := production.dump
postgres_role := thibaut
postgres_database := tps_development

up:
	overmind start --any-can-die -f Procfile.dev

connect:
	overmind connect -n demat-social-app

restore_prod:
	[ -e ./.overmind.sock ] && overmind stop
	cp ../dumps/$(postgres_dump) ./
	psql -U $(postgres_role) -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$(postgres_database)' AND pid <> pg_backend_pid();"
	dropdb --if-exists -U $(postgres_role) $(postgres_database)
	createdb -U $(postgres_role) $(postgres_database)
	pg_restore -U $(postgres_role) -d $(postgres_database) -x -O $(postgres_dump)
	rm ./$(postgres_dump)
	[ -e ./.overmind.sock ] && overmind restart
	bin/migrate-data.sh
	bin/rails db:seed

dump_dev:
	[ -e ./.overmind.sock ] && overmind stop
	pg_dump -U $(postgres_role) $(postgres_database) > log/backup.sql
	cp log/backup.sql log/backup-$(current_date).sql
	[ -e ./.overmind.sock ] && overmind restart

load_dev:
	[ -e ./.overmind.sock ] && overmind stop
	dropdb -U $(postgres_role) $(postgres_database)
	createdb -U $(postgres_role) $(postgres_database)
	psql -U $(postgres_role) $(postgres_database) < log/backup.sql
	[ -e ./.overmind.sock ] && overmind restart

# ex : make rspec_unit nb_workers=2
# use a log file to split the tests by runtime in each worker
rspec_unit:
	@rm -rf tmp/capybara/* && echo '🧹 clean capybara tmp files'
	@if [ ! -e ./config/parallel_runtime_rspec_unit_test.log ]; then \
		echo '✨ first launch'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --exclude-pattern 'spec/system/**/*_spec.rb' --test-options "--format ParallelTests::RSpec::RuntimeLogger --out ./config/parallel_runtime_rspec_unit_test.log"; \
	else \
		echo '🚀 optimised launch'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime --exclude-pattern 'spec/system/**/*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_unit_test.log; \
	fi

# ex : make rspec_system nb_workers=2
# use a log file to split the tests by runtime in each worker
rspec_system:
	@rm -rf tmp/capybara/* && echo '🧹 clean capybara tmp files'
	@if [ ! -e ./config/parallel_runtime_rspec_system_test.log ]; then \
		echo '✨ first launch'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec spec/system/**/*_spec.rb --test-options "--format ParallelTests::RSpec::RuntimeLogger --out ./config/parallel_runtime_rspec_system_test.log"; \
	else \
		echo '🚀 optimised launch'; \
		bundle exec parallel_rspec -n $(nb_workers) -t rspec --group-by runtime spec/system/**/*_spec.rb --runtime-log ./config/parallel_runtime_rspec_system_test.log; \
	fi

rspec_system_visual:
	MAKE_IT_SLOW=true NO_HEADLESS=1 bundle exec rspec $(file)

rspec_parallel_file:
	bundle exec parallel_rspec -n $(nb_workers) -t rspec $(file) --test-options "--format progress"


# # Drops the current development database and create a new empty one
# # First start database container in a terminal with 'make dbconsole'
# dbcreate:
# 	docker exec -i demat-social-data /bin/bash -c "dropdb --if-exists -U $(postgres_role) $(postgres_database)"
# 	docker exec -i demat-social-data /bin/bash -c "createdb -U $(postgres_role) $(postgres_database)"

# # Reloads the database schema, runs the migrations, and seeds the database
# dbinit:
# 	docker-compose run -u demat-social --name webapp-console -e RAILS_ENV=development --rm  webapp-main /bin/bash -c "bin/rails db:schema:load && bin/rails db:migrate && bin/rails db:seed"

# # Run the rspec tests for a specific file
# # Usage: make rspec file=spec/models/user_spec.rb
# # the test database must be created in the db container
# # Tip : use the rails run spec VSCode extention with the setting : custom command : "make rspec file=",
# # https://github.com/thadeu/vscode-run-rspec-file
# # and use the shortcut to run the tests strait from your editor
# # ⚠️ Need the database to be up and running, make up is your friend
# rspec:
# 	docker-compose run -u demat-social --name webapp-test -e RAILS_ENV=test --rm webapp-main bundle exec rspec --color $(file)

# # ex : make local-ci nb_workers=2
# local-ci:
# 	docker-compose run -u demat-social --name webapp-test -e RAILS_ENV=test --rm webapp-main time ./bin/local_ci.sh $(nb_workers)
