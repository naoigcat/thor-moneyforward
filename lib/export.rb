class Entrypoint < Thor
  desc "export", "Export csv from MoneyForward"
  def export # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    driver = nil
    begin
      Retryable.configure do |config|
        config.exception_cb = proc do |exception|
          puts "exception=#{exception}"
          driver&.quit
          driver = nil
        end
      end
      Retryable.retryable(tries: 3) do
        driver = Selenium::WebDriver.for :remote, url: "http://selenium:4444/wd/hub", desired_capabilities: :chrome
        driver.manage.timeouts.implicit_wait = 30
        driver.navigate.to "https://moneyforward.com"
        driver.find_element(:class, "web-sign-in").click
        driver.find_element(:class, "ssoLink").click
        driver.find_element(:name, "mfid_user[email]").send_keys ENV["USERNAME"]
        driver.find_element(:tag_name, "form").submit
        driver.find_element(:name, "mfid_user[password]").send_keys ENV["PASSWORD"]
        driver.find_element(:tag_name, "form").submit
        driver.find_element(:class, "mf-icon-pie-chart").find_element(:xpath, "..").click
        driver.get "file:///home/seluser/Downloads/"
        driver.page_source.scan(/(?<=addRow\(")download(?: \(\d+\))?(?=")/).tap do |files|
          next unless files.empty?

          Enumerator.new do |yielder|
            date = Date.new(2015, 1)
            while date <= Date.today
              yielder << date
              date = date.next_month
            end
          end.each do |date|
            driver.get "https://moneyforward.com/cf/csv?year=#{date.year}&month=#{date.month}"
            sleep 3
          end
          driver.get "file:///home/seluser/Downloads/"
          break driver.page_source.scan(/(?<=addRow\(")download(?: \(\d+\))?(?=")/)
        end.sort_by do |file|
          file.match(/(?<=\().*(?=\))/).to_s.to_i
        end.map do |file|
          driver.get "file:///home/seluser/Downloads/#{file}"
          driver.find_element(:tag_name, "pre").text
        end.map.with_index do |text, index|
          next text if index.zero?

          text.lines.drop(1).reverse.map(&:chomp).join("\n")
        end.join("\n").yield_self do |text|
          Pathname.new("00000000.csv").write text
        end
      end
    ensure
      driver&.quit
    end
  end
end
