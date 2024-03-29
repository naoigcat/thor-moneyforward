#!/usr/bin/env ruby
require "bundler"
Bundler.require
Pathname.glob("lib/**.rb").each(&method(:load))

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
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      Selenium::WebDriver.for :remote, url: "http://selenium:4444/wd/hub", options: options
    end
  end
end

Value = Struct.new(:date, :content, :price) do
  def initialize(date, content, price)
    super(Date.parse(date), content.gsub(/\u301c/, "\uff5e").slice(0, 50), price.sub(/\u00a5/, "").to_i)
  end
end

Entrypoint.start
