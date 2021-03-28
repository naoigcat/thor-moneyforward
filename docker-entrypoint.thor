#!/usr/bin/env ruby
require "bundler"
Bundler.require

class Entrypoint < Thor
  desc "download", "Download csv from MoneyForward"
  def download # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
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

  desc "upload", "Upload csv to moneyforward"
  def upload # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
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
      source = Pathname.glob("*.csv").reject do |path|
        path.basename(".csv").to_s == "00000000"
      end.each do |path|
        CSV.foreach(path, headers: true).with_index do |row, index|
          next unless row["ID"].nil? || row["ID"].empty?
          next unless target.grep(Value.new(row["日付"], row["内容"], row["金額（円）"])).empty?

          puts format("%04d #{row.inspect.gsub(/%/, "%%")}", index)
          Retryable.retryable(tries: 3) do
            unless driver
              driver = Selenium::WebDriver.for :remote, url: "http://selenium:4444/wd/hub", desired_capabilities: :chrome
              driver.manage.timeouts.implicit_wait = 30
              driver.navigate.to "https://moneyforward.com"
              driver.find_element(:class, "web-sign-in").click
              driver.find_element(:class, "ssoLink").click
              driver.find_element(:name, "mfid_user[email]").send_keys(ENV["USERNAME"])
              driver.find_element(:tag_name, "form").submit
              driver.find_element(:name, "mfid_user[password]").send_keys(ENV["PASSWORD"])
              driver.find_element(:tag_name, "form").submit
              driver.find_element(:class, "mf-icon-pie-chart").find_element(:xpath, "..").click
              driver.find_element(:class, "mf-mb-medium").find_element(:tag_name, "button").click
            end
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

  no_commands do
    module ::Selenium
      module WebDriver
        class Element
          def select_by_text(text)
            Selenium::WebDriver::Support::Select.new(self).tap do |element|
              element.options.find do |option|
                option.text.match?(/^#{text} *\(/)
              end.tap do |option|
                element.select_by(:value, option&.attribute("value") || "0")
              end
            end
          end
        end
      end
    end

    class Value < Struct.new(:date, :content, :price)
      def initialize(date, content, price)
        super(Date.parse(date), content.gsub(/\u301c/, "\uff5e").slice(0, 50), price.sub(/\u00a5/, "").to_i)
      end
    end
  end
end

Entrypoint.start
