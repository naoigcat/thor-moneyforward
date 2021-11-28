class Entrypoint < Thor
  desc "sub_account [NAME]", "Complement the sub account in MoneyForward"
  def sub_account(name) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
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
      Enumerator.new do |yielder|
        date = Date.new(2015, 1)
        while date <= Date.today
          yielder << date
          date = date.next_month
        end
      end.each do |date|
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
            driver.find_element(:class, "mf-icon-pie-chart").find_element(:xpath, "..").click
          end
          driver.find_element(:xpath, "//div[contains(@class, 'uikit-year-month-select-dropdown')]").click
          driver.find_element(:xpath, "//div[contains(@class, 'uikit-year-month-select-dropdown-year-part') and text()='#{date.year}']").tap do |year|
            driver.action.move_to(year).perform
            year.find_element(:xpath, "*/a[text()='#{date.month}']").tap do |month|
              driver.action.move_to(month).perform
              month.click
            end
          end
          sleep 3
          puts date
          loop do
            cells = driver.find_elements(:xpath, "//table[@id='cf-detail-table']//td[contains(@class, 'sub_account_id_hash')]").select do |cell|
              cell.find_element(:tag_name, "span").text.match?(/^なし$/)
            end
            break if cells.empty?

            driver.action.move_to(cells.first).perform
            cells.first.click
            cells.first.find_element(:tag_name, "select").select_by_text(name)
            sleep 10
          end
        end
      end
    ensure
      driver&.quit
    end
  end
end
