# OpalProxy

Opal Proxy provides a dynamic interface to JavaScript objects in Opal,
allowing seamless property access, method calls, and Promise handling using idiomatic Ruby syntax.

## Installation

Add this line to your Gemfile:

```ruby
gem 'opal_proxy'
```

Execute:

```bash
bundle install
```


## Document example

```ruby
require "js/proxy"

class Document < JSProxy
  def initialize
    super($$.document)
  end
end

document = Document.new
headers = document.querySelectorAll("h1") # or query_selector_all
headers.each do |h1|
  h1.text_content = "Opal is great!" # or textContent
end

document.body.style.background_color = "lightblue"
document.body.style.font_family = "Arial, sans-serif"
document.body.style.color = "darkblue"
```

## Window example

```ruby
require "js/proxy"

class Window < JSProxy
  def initialize
    super($$.window)
  end
end

window = Window.new
window.alert "Hello world!"
window.set_timeout(-> {
  puts "1. Timeout test OK (1s delay)"
}, 1000)
window.fetch("https://jsonplaceholder.typicode.com/todos/1")
  .then do |response|
    response.json().then do |data|
      puts "5. Fetched: #{data["title"]}"
      document.get_element_by_id("output").inner_html += "<p>5. Fetched: #{data["title"]}</p>"
    end
  end
```

## JQuery example

```ruby
jquery_lib = document.create_element('script')
jquery_lib.src = "https://code.jquery.com/jquery-3.7.1.min.js"
document.head.append_child(jquery_lib)

class JQuery < JS::Proxy
  def initialize(node)
    super(`$(node)`)
  end
end

jquery_lib.onload = -> {
  document = JQuery.new($$.document)
  document.ready do
    paragraph = document.create_element('p')
    paragraph.id = "my-paragraph"
    paragraph.text_content = "If you click on me, I will disappear."
    document.body.append_child(paragraph)
    JQuery.new("p").click(&:hide)
  end
}
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/josephschito/opal_proxy.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
