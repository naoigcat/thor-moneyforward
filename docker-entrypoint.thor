#!/usr/bin/env ruby
require "bundler"
Bundler.require

require_relative "lib/delete_rules"
require_relative "lib/export"
require_relative "lib/import"
require_relative "lib/sub_account"

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

    def self.driver
      Selenium::WebDriver.for :remote, url: "http://selenium:4444/wd/hub", capabilities: Selenium::WebDriver::Remote::Capabilities.chrome(
        "goog:chromeOptions" => {
          "args" => [
            "window-size=1920,1080",
          ],
        },
      )
    end
  end
end

Value = Struct.new(:date, :content, :price) do
  def initialize(date, content, price)
    super(Date.parse(date), content.gsub(/\u301c/, "\uff5e").slice(0, 50), price.sub(/\u00a5/, "").to_i)
  end
end

Entrypoint.start
