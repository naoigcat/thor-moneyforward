class Entrypoint < Thor
  desc "import", "Import csv to moneyforward"
  def import # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    target = Pathname.new("00000000.csv").yield_self do |path|
      next [] unless path.exist?

      CSV.read(path, headers: true).map do |row|
        Value.new(row["日付"], row["内容"], row["金額（円）"])
      end
    end
    driver = nil
    Retryable.configure do |config|
      config.exception_cb = proc do |exception|
        puts "exception=#{exception}"
        driver&.quit
        driver = nil
      end
    end
    begin
      Pathname.glob("*.csv").reject do |path|
        path.basename(".csv").to_s == "00000000"
      end.each do |path|
        CSV.foreach(path, headers: true).with_index do |row, index|
          next unless row["ID"].nil? || row["ID"].empty?
          next unless target.grep(Value.new(row["日付"], row["内容"], row["金額（円）"])).empty?

          puts format("%04d #{row.inspect.gsub(/%/, "%%")}", index)
          Retryable.retryable(tries: 3) do
            unless driver
              driver = Selenium::WebDriver.driver
              driver.manage.timeouts.implicit_wait = 30
              driver.navigate.to "https://moneyforward.com/sign_in"
              driver.find_element(:class, "ssoLink").click
              driver.find_element(:name, "mfid_user[email]").send_keys(ENV["USERNAME"])
              driver.find_element(:tag_name, "form").submit
              driver.find_element(:name, "mfid_user[password]").send_keys(ENV["PASSWORD"])
              driver.find_element(:tag_name, "form").submit
            end
            driver.navigate.to "https://moneyforward.com/cf"
            driver.find_element(:class, "mf-mb-medium").find_element(:tag_name, "button").click
            driver.find_element(:id, "updated-at").tap(&:clear).send_keys(row["日付"].gsub(/-/, "/"))
            price = row["金額（円）"].sub(/\u00a5/, "").to_i
            if price.positive?
              driver.find_element(:class, "plus-payment").click
            else
              driver.find_element(:class, "minus-payment").click
            end
            driver.find_element(:id, "appendedPrependedInput").tap(&:clear).send_keys(price.abs)
            driver.find_element(:id, "user_asset_act_sub_account_id_hash").select_by_text(row["保有金融機関"])
            driver.find_element(:id, "js-large-category-selected").click
            driver.find_element(:xpath, "//a[text()='#{row["大項目"]}' and @class='l_c_name']").click
            driver.find_element(:id, "js-middle-category-selected").click
            driver.find_element(:xpath, "//a[text()='#{row["中項目"]}' and @class='m_c_name']").click
            driver.find_element(:id, "js-content-field").tap(&:clear).send_keys(row["内容"][0...50])
            driver.find_element(:id, "submit-button").click
            Selenium::WebDriver::Wait.new(timeout: 30).until do
              driver.find_element(:id, "confirmation-button").displayed?
            end
            driver.find_element(:id, "confirmation-button").click
          end
        end
      end
    ensure
      driver&.quit
    end
  end
end
