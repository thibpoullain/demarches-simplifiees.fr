#!/usr/bin/env bash

# bundle exec brakeman
# bundle exec rake lint
# bundle exec rake zeitwerk:check

# To measure the execution time of the test suite, and parallel them based on the time they take to run
# Run tests with this option : --format ParallelTests::RSpec::RuntimeLogger --out tmp/parallel_runtime_rspec.log
bundle exec rake parallel:spec

# yarn test
# bundle exec rails assets:precompile
