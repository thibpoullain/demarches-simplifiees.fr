require 'capybara/rails'
require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'capybara/email/rspec'
require 'selenium/webdriver'

def setup_driver(driver)
  if ENV['MAKE_IT_SLOW'].present?
    driver.browser.network_conditions = {
      offline: false,
      latency: 800,
      download_throughput: 1024000,
      upload_throughput: 1024000
    }
  end

  if ENV['JS_LOG'].present?
    driver.browser.on_log_event(:console) do |event|
      puts event.args if event.type == ENV['JS_LOG'].downcase.to_sym
    end
  end

  driver
end

Capybara.register_driver :selenium_chrome do |app|
  args = ['disable-gpu', 'disable-dev-shm-usage', 'window-size=1400,900', 'mute-audio', 'no-sandbox']
  options = Selenium::WebDriver::Chrome::Options.new(args: args)
  setup_driver(Capybara::Selenium::Driver.new(app, browser: :chrome, options: options))
end

Capybara.register_driver :selenium_chrome_headless do |app|
  args = [
    'headless', 'disable-gpu', 'disable-software-rasterizer', 'disable-dev-shm-usage',
    'window-size=1400,900', 'mute-audio', 'no-sandbox'
  ]
  options = Selenium::WebDriver::Chrome::Options.new(args: args)
  setup_driver(Capybara::Selenium::Driver.new(app, browser: :chrome, options: options))
end

Capybara.default_driver         = :selenium_chrome
Capybara.javascript_driver      = :selenium_chrome_headless
Capybara.default_max_wait_time  = 4
Capybara.ignore_hidden_elements = false
Capybara.enable_aria_label      = true
Capybara.disable_animation      = true

# Save a snapshot of the HTML page when an integration test fails
Capybara::Screenshot.autosave_on_failure = true
# Keep only the screenshots generated from the last failing test suite
Capybara::Screenshot.prune_strategy = :keep_last_run
# Tell Capybara::Screenshot how to take screenshots when using the headless_chrome driver
Capybara::Screenshot.register_driver :selenium_chrome_headless do |driver, path|
  driver.browser.save_screenshot(path)
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by ENV['NO_HEADLESS'] ? :selenium_chrome : :selenium_chrome_headless
  end

  # Set the user preferred language before Javascript system specs.
  #
  # System specs without Javascript run in a Rack stack, and respect the Accept-Language value.
  # However specs using Javascript are run into a Headless Chrome, which doesn't support setting
  # the default Accept-Language value reliably.
  # So instead we set the locale cookie explicitly before each Javascript test.
  config.before(:each, type: :system, js: true) do
    visit '/' # Webdriver needs visiting a page before setting the cookie
    Capybara.current_session.driver.browser.manage.add_cookie(
      name: :locale,
      value: Rails.application.config.i18n.default_locale
    )
  end

  # Examples tagged with :capybara_ignore_server_errors will allow Capybara
  # to continue when an exception in raised by Rails.
  # This allows to test for error cases.
  config.around(:each, :capybara_ignore_server_errors) do |example|
    Capybara.raise_server_errors = false

    example.run
  ensure
    Capybara.raise_server_errors = true
  end
end
