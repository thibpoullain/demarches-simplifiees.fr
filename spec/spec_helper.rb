# This file was generated by the `rails generate rspec:install` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# The `.rspec` file contains `--require rails_helper`, which requires spec_helper.rb,
# causing this file to always be loaded, without a need to explicitly require it in any
# files.
#
# Given that it is always loaded, you are encouraged to keep this file as
# light-weight as possible. Requiring heavyweight dependencies from this file
# will add to the boot time of your test suite on EVERY test run, even for an
# individual file that may not need all of that loaded. Instead, consider making
# a separate helper file that requires the additional dependencies and performs
# the additional setup, and require it from the spec files that actually need
# it.
#
# The `.rspec` file also contains a few flags that are not defaults but that
# users commonly want.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
#
#
require 'simplecov' if ENV["CI"] || ENV["COVERAGE"] # see config in .simplecov file

require 'rspec/retry'

SECURE_PASSWORD = 'my-s3cure-p4ssword'

RSpec.configure do |config|
  config.filter_run_excluding disable: true
  config.color = true
  config.tty = true

  config.example_status_persistence_file_path = 'failing_specs.txt'
  config.run_all_when_everything_filtered = true
  config.filter_run :focus => true

  config.order = 'random'
  # Fix the seed not changing between runs when using Spring
  # See https://github.com/rails/spring/issues/113
  config.seed = srand % 0xFFFF unless ARGV.any? { |arg| arg =~ /seed/ || arg =~ /rand:/ }

  RSpec::Matchers.define :have_same_attributes_as do |expected, options|
    match do |actual|
      ignored = [:id, :procedure_id, :updated_at, :created_at]
      if options.present? && options[:except]
        ignored = ignored + options[:except]
      end
      actual.attributes.with_indifferent_access.except(*ignored) == expected.attributes.with_indifferent_access.except(*ignored)
    end
  end

  # Asserts that a given select element exists in the page,
  # and that the option(s) with the given value(s) are selected.
  #
  # Usage: expect(page).to have_selected_value('Country', selected: 'Australia')
  #
  # For large lists, this is much faster than `have_select(location, selected: value)`,
  # as it doesn’t check that every other options are not selected.
  RSpec::Matchers.define(:have_selected_value) do |select_locator, options|
    match do |page|
      values = options[:selected].is_a?(String) ? [options[:selected]] : options[:selected]

      select_element = page.first(:select, select_locator)
      select_element && values.all? do |value|
        select_element.first(:option, value).selected?
      end
    end
  end
end

RSpec.configure do |config|
  # show retry status in spec process
  config.verbose_retry = true
  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  config.retry_count_condition = proc do |ex|
    if ENV["CI"] == "true" && ex.metadata[:js]
      3
    else # in dev we want to have real error fast
      1
    end
  end

  # callback to be run between retries
  config.retry_callback = proc do |ex|
    # run some additional clean up task - can be filtered by example metadata
    if ex.metadata[:js]
      Capybara.reset!
    end
  end
end
