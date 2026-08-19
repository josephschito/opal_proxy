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
# ... including document

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
  .then { |response| response.json }
  .then do |data|
    puts "5. Fetched: #{data["title"]}"
    document.get_element_by_id("output").inner_html += "<p>5. Fetched: #{data["title"]}</p>"
  end
  .catch { |error| warn error["message"] }
```

Promise callbacks automatically unwrap returned `JS::Proxy` and `JS::Promise` values,
so native Promise flattening works across chained `then`, `catch`, and `finally` calls.

## Interop behavior

Property lookup tries the original name first, then camelCase and common JavaScript
acronyms such as `HTML`, `URL`, and `URI`. For example, both `inner_html` and
`document_uri` map to their DOM equivalents.

JavaScript properties that collide with Ruby methods can always be accessed with `[]`:

```ruby
proxy["count"]
proxy["class"]
```

When a Ruby block is passed to a JavaScript method, it is appended as the final callback
argument. The callback receives its JavaScript `this` value first, followed by the native
callback arguments, all wrapped when necessary:

```ruby
target.add_event_listener("click") do |receiver, event|
  event.prevent_default
  puts receiver
end
```

`JS::Proxy` is enumerable for JavaScript iterable and array-like objects, including
arrays, `Set`, `Map`, `NodeList`, and objects with numeric indexes and a `length`.

## JQuery example

```ruby
require "js/proxy"
# ... including document

doc = Document.new
jquery_script = doc.createElement('script')
jquery_script.src = "https://code.jquery.com/jquery-3.7.1.min.js"
doc.head.appendChild(jquery_script)
jquery_script.onload = -> {
  class JQuery < JS::Proxy
    def initialize(node)
      super(`$(node)`)
    end
  end

  document = JQuery.new($$.document)
  document.ready do
    paragraph = doc.createElement('p')
    paragraph.text_content = "If you click on me, I will disappear."
    doc.body.appendChild(paragraph)
    JQuery.new("p").click(&:hide)
  end
}
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/josephschito/opal_proxy.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
