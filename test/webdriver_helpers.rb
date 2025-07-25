module WebdriverHelpers
  def setup
    super

    @driver = Selenium::WebDriver.for :chrome, options: headless_options
  end

  def teardown
    super

    @driver.quit
  end

  def index_url
    file_path = File.expand_path("fixtures/basic_index.html", __dir__)
    url = "file://#{file_path}"
  end

  private

  def compile_opal(code)
    lib = Opal::Builder.build('js/proxy').to_s
    compiled_code = Opal::Compiler.new(code, requirable: false).compile
    full_js = "#{lib}\n#{compiled_code}"
  end

  def headless_options
    Selenium::WebDriver::Chrome::Options.new.tap do |opts|
      opts.add_argument("--disable-gpu")
      opts.add_argument("--no-sandbox")
      return if ENV["NO_HEADLESS"]
      opts.add_argument("--headless=new")
    end
  end

  extend self
end
