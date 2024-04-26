#!/usr/bin/env bash

export RAILS_ENV=test

bundle exec brakeman
bundle exec rake lint
bundle exec rake zeitwerk:check
yarn test
bundle exec rails assets:precompile

rm -rf log/capybara_unit_test/*
if [ -f "config/parallel_runtime_rspec_unit_test.log" ]; then
  bundle exec parallel_rspec -n $1 -t rspec --group-by runtime --exclude-pattern 'spec/system/**/*_spec.rb' --runtime-log ./config/parallel_runtime_rspec_unit_test.log
else
  bundle exec parallel_rspec -n $1 -t rspec --exclude-pattern 'spec/system/**/*_spec.rb' --test-options "--format ParallelTests::RSpec::RuntimeLogger --out ./config/parallel_runtime_rspec_unit_test.log"
fi
cp tmp/capybara/* log/capybara_unit_test

rm -rf log/capybara_unit_test/*
if [ -f "config/parallel_runtime_rspec_system_test.log" ]; then
    bundle exec parallel_rspec -n $1 -t rspec --group-by runtime spec/system/**/*_spec.rb --runtime-log ./config/parallel_runtime_rspec_system_test.log
else
    echo "Log file for system tests does not exist. Creating a new log file."
    bundle exec parallel_rspec -n $1 -t rspec spec/system/**/*_spec.rb --test-options "--format ParallelTests::RSpec::RuntimeLogger --out ./config/parallel_runtime_rspec_system_test.log"
fi
cp tmp/capybara/* log/capybara_system_test
