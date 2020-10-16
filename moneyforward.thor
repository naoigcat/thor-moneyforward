#!/usr/bin/env ruby
require "bundler"
Bundler.require

module Selenium
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

class Moneyforward < Thor
  desc "upload [Username] [Password] [Path]", "Upload csv to moneyforward"
  def upload(username, password, path) # rubocop:disable Metrics/AbcSize
    require "csv"
    require "rbconfig"
    cask "chromedriver"
    cask "google-chrome"

    data = CSV.read(path, headers: true, encoding: "CP932:UTF-8")
    index = 0
    index_at_error = -1

    driver = nil
    begin
      Selenium::WebDriver::Chrome::Service.driver_path = "/usr/local/bin/chromedriver"
      options = Selenium::WebDriver::Chrome::Options.new
      driver&.quit
      driver = Selenium::WebDriver.for :chrome, options: options
      driver.manage.timeouts.implicit_wait = 30
      driver.navigate.to "https://moneyforward.com"
      driver.find_element(:class, "web-sign-in").click
      driver.find_element(:class, "ssoLink").click
      driver.find_element(:name, "mfid_user[email]").send_keys(username)
      driver.find_element(:tag_name, "form").submit
      driver.find_element(:name, "mfid_user[password]").send_keys(password)
      driver.find_element(:tag_name, "form").submit
      driver.find_element(:class, "mf-icon-pie-chart").find_element(:xpath, "..").click
      driver.find_element(:class, "mf-mb-medium").find_element(:tag_name, "button").click
      while (row = data[index])
        if row["ID"]
          index += 1
          next
        end

        puts format("%04d #{row.inspect.gsub(/%/, "%%")}", index)
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
        index += 1
      end
    rescue
      raise if index_at_error == index

      index_at_error = index
      retry
    ensure
      driver&.quit
    end
  end

  no_commands do
    def cask(name)
      return unless RbConfig::CONFIG["host_os"].match?(/darwin|mac os/)
      return if IO.popen("/usr/local/bin/brew list -1 --cask", &:read).split(/\n/).include?(name)

      system("/usr/local/bin/brew", "cask", "install", name)
    end
  end
end

Moneyforward.start %w[upload] + ARGV
