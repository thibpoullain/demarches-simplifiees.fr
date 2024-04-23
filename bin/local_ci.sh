#!/usr/bin/env bash

export RAILS_ENV=test

bundle exec brakeman
bundle exec rake lint
bundle exec rake zeitwerk:check

if [ -f "config/parallel_runtime_rspec_unit_test.log" ]; then
  bundle exec parallel_rspec -t rspec --group-by runtime --exclude-pattern 'spec/system/**/*_spec.rb' --runtime-log config/parallel_runtime_rspec_unit_test.log
else
  bundle exec parallel_rspec -t rspec --exclude-pattern 'spec/system/**/*_spec.rb' --test-options "--format ParallelTests::RSpec::RuntimeLogger --out config/parallel_runtime_rspec_unit_test.log"
fi

if [ -f "config/parallel_runtime_rspec_system_test.log" ]; then
    bundle exec parallel_rspec -t rspec --group-by runtime spec/system/**/*_spec.rb --runtime-log config/parallel_runtime_rspec_unit_test.log
else
    echo "Log file for system tests does not exist. Creating a new log file."
    bundle exec parallel_rspec -t rspec spec/system/**/*_spec.rb --test-options "--format ParallelTests::RSpec::RuntimeLogger --out config/parallel_runtime_rspec_system_test.log"
fi

yarn test
bundle exec rails assets:precompile
