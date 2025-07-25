# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../webdriver_helpers"
require "selenium-webdriver"

class Proxy < Minitest::Test
  include WebdriverHelpers

  def test_document_title
    opal_code = opal_code_prepended_by(document_wrapper) do
      <<~RUBY
        document = Document.new
        document.title = "Opal Proxy Test"
      RUBY
    end

    @driver.navigate.to(index_url)
    @driver.execute_script(compile_opal(opal_code))

    assert_equal "Opal Proxy Test", @driver.title
  end

  def test_window_alert
    opal_code = opal_code_prepended_by(window_wrapper) do
      <<~RUBY
        window = Window.new
        window.alert("Hello from Opal Proxy!")
      RUBY
    end

    @driver.navigate.to(index_url)
    @driver.execute_script(compile_opal(opal_code))

    alert = @driver.switch_to.alert
    assert_equal "Hello from Opal Proxy!", alert.text
    alert.accept
  end

  def test_jquery_proxy
    opal_code = opal_code_prepended_by(document_wrapper, jquery_wrapper) do
      <<~RUBY
        doc = Document.new
        jquery_lib = doc.createElement('script')
        jquery_lib.src = "https://code.jquery.com/jquery-3.7.1.min.js"
        doc.head.appendChild(jquery_lib)

        jquery_lib.onload = -> {
          document = JQuery.new($$.document)
          document.ready do
            paragraph = doc.createElement('p')
            paragraph.id = "my-paragraph"
            paragraph.text_content = "If you click on me, I will disappear."
            doc.body.appendChild(paragraph)
            JQuery.new("p").click(&:hide)
          end
        }
      RUBY
    end

    @driver.navigate.to(index_url)
    @driver.execute_script(compile_opal(opal_code))

    Selenium::WebDriver::Wait.new(:timeout => 10).until { @driver.find_element(id: "my-paragraph") }
    my_paragraph = @driver.find_element(id: "my-paragraph")
    assert my_paragraph.text, "Paragraph should be present before click"
    assert !my_paragraph.attribute("style").include?("display: none")
    my_paragraph.click
    Selenium::WebDriver::Wait.new(:timeout => 10).until { @driver.find_element(id: "my-paragraph").attribute("style").include?("display: none") }
    assert my_paragraph.attribute("style").include?("display: none")
  end

  def test_fetch_proxy
    opal_code = opal_code_prepended_by(window_wrapper, document_wrapper) do
      <<~RUBY
        window = Window.new
        document = Document.new
        create_p = ->(content) {
          paragraph = document.create_element('p')
          paragraph.text_content = content
          document.body.append_child(paragraph)
        }
        window
          .fetch("https://jsonplaceholder.typicode.com/todos/1")
          .then do |response|
            response.json().then do |data|
              create_p.call("id " + data["id"].to_s)
              create_p.call("userId " + data["userId"].to_s)
              create_p.call("title " + data["title"].to_s)
              create_p.call("completed " + data["completed"].to_s)
            end
          end
      RUBY
    end

    @driver.navigate.to(index_url)
    @driver.execute_script(compile_opal(opal_code))

    Selenium::WebDriver::Wait.new(:timeout => 10).until do
      @driver.find_elements(tag_name: "p").size >= 4
    end

    texts = @driver.find_elements(tag_name: "p").map(&:text)
    assert texts.include?("id 1")
    assert texts.include?("userId 1")
    assert texts.include?("title delectus aut autem")
    assert texts.include?("completed false")
  end

  private

  def opal_code_prepended_by(*proxied, &block)
    <<~RUBY
      #{proxied.join("\n")}

      #{block.call if block_given?}
    RUBY
  end

  def window_wrapper
    <<~RUBY
      class Window < JS::Proxy
        def initialize
          super($$.window)
        end
      end
    RUBY
  end

  def document_wrapper
    <<~RUBY
      class Document < JS::Proxy
        def initialize
          super($$.document)
        end
      end
    RUBY
  end

  def jquery_wrapper
    <<~RUBY
      class JQuery < JS::Proxy
        def initialize(node)
          super(`$(node)`)
        end
      end
    RUBY
  end
end
