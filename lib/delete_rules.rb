class Entrypoint < Thor
  desc "delete_rules", "Complement the sub account in MoneyForward"
  def delete_rules # rubocop:disable Metrics/AbcSize
    driver = nil
    begin
      Retryable.configure do |config|
        config.exception_cb = proc do |exception|
          puts "exception=#{exception}"
          driver&.quit
          driver = nil
          sleep 30
        end
      end
      Retryable.retryable(tries: Float::INFINITY) do
        unless driver
          driver = Selenium::WebDriver.driver
          driver.manage.timeouts.implicit_wait = 30
          driver.navigate.to "https://moneyforward.com"
          driver.find_element(:class, "web-sign-in").click
          driver.find_element(:class, "ssoLink").click
          driver.find_element(:name, "mfid_user[email]").send_keys ENV["USERNAME"]
          driver.find_element(:tag_name, "form").submit
          driver.find_element(:name, "mfid_user[password]").send_keys ENV["PASSWORD"]
          driver.find_element(:tag_name, "form").submit
        end
        driver.navigate.to "https://moneyforward.com/profile/rule"
        loop do
          contents = driver.find_elements(:xpath, "//td[contains(@class,'content-deletes')]/a")
          break if contents.empty?

          contents.first.click
          driver.switch_to.alert.accept
        end
        loop do
          contents = driver.find_elements(:xpath, "//td[contains(@class,'content-delete')]/a")
          break if contents.empty?

          contents.first.click
          driver.switch_to.alert.accept
        end
      end
    ensure
      driver&.quit
    end
  end
end
