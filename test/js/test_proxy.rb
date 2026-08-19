# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../webdriver_helpers"
require "selenium-webdriver"

class ProxyTest < Minitest::Test
  include WebdriverHelpers

  def test_property_access_name_conversion_and_introspection
    run_opal <<~RUBY
      native = `({
        camelCase: "camel",
        innerHTML: "markup",
        getURLValue: function() { return "value"; },
        htmlFor: "form",
        url: "lower",
        URL: "upper"
      })`
      proxy = JS::Proxy.new(native)
      methods_before = proxy.native_methods

      missing_raises = begin
        proxy.definitely_missing
        false
      rescue NoMethodError
        true
      end

      `\#{native}.dynamicValue = 42`
      methods_after = proxy.native_methods

      values = [
        proxy.camel_case,
        proxy.inner_html,
        proxy.get_url_value,
        proxy.html_for,
        proxy.url,
        proxy["URL"],
        proxy.respond_to?(:camel_case),
        proxy.respond_to?(:definitely_missing),
        proxy.respond_to?(:new_property=),
        missing_raises,
        methods_before.include?("getURLValue"),
        methods_before.include?("get_url_value"),
        methods_after.include?("dynamicValue"),
        methods_after.include?("dynamic_value")
      ]

      `window.__result = \#{values.to_n}`
    RUBY

    assert_equal [
      "camel", "markup", "value", "form", "lower", "upper",
      true, false, true, true, true, true, true, true
    ], result
  end

  def test_property_and_index_assignment_unwrap_values_and_return_assigned_value
    run_opal <<~RUBY
      proxy = JS::Proxy.new(`({})`)
      child = JS::Proxy.new(`({ name: "child" })`)

      proxy.new_value = 7
      proxy.document_uri = "urn:test"
      primitive_return = proxy.public_send(:[]=, "count", 9)
      proxy_return = proxy.public_send(:[]=, "child", child)

      values = [
        proxy.new_value,
        proxy["documentURI"],
        proxy["count"],
        primitive_return,
        proxy_return.equal?(child),
        `\#{proxy.to_n}.child === \#{child.to_n}`,
        proxy.child.name,
        proxy.native.is_a?(Native::Object)
      ]

      proxy.native = `({ replacement: true })`
      values << proxy.replacement

      `window.__result = \#{values.to_n}`
    RUBY

    assert_equal [7, "urn:test", 9, 9, true, true, "child", true, true], result
  end

  def test_native_method_invocation_preserves_receiver_and_wraps_results
    run_opal <<~RUBY
      proxy = JS::Proxy.new(`({
        count: 1,
        increment: function(amount) {
          this.count += amount;
          return this;
        },
        nested: function() {
          return { value: this.count };
        }
      })`)

      returned = proxy.increment(4)
      nested = proxy.nested

      values = [
        proxy["count"],
        returned.is_a?(JS::Proxy),
        `\#{returned.to_n} === \#{proxy.to_n}`,
        nested.is_a?(JS::Proxy),
        nested.value
      ]

      `window.__result = \#{values.to_n}`
    RUBY

    assert_equal [5, true, true, true, 5], result
  end

  def test_generic_callback_wraps_receiver_and_arguments_without_calling_subclass_constructor
    run_opal <<~RUBY
      `window.__callback_host = {
        context: { label: "context" },
        invoke: function(prefix, callback) {
          var returned = callback.call(this.context, { value: 4 }, 5);
          return {
            prefix: prefix,
            returned: returned,
            sameContext: returned === this.context
          };
        }
      }`

      class CallbackHost < JS::Proxy
        def initialize
          super(`window.__callback_host`)
        end
      end

      callback_receiver_is_proxy = false
      callback_argument_is_proxy = false
      callback_values = nil

      returned = CallbackHost.new.invoke("prefix") do |receiver, object, number|
        callback_receiver_is_proxy = receiver.instance_of?(JS::Proxy)
        callback_argument_is_proxy = object.instance_of?(JS::Proxy)
        callback_values = [receiver.label, object.value, number]
        receiver
      end

      values = [
        callback_receiver_is_proxy,
        callback_argument_is_proxy,
        callback_values,
        returned.prefix,
        returned.same_context,
        returned.returned.label
      ]

      `window.__result = \#{values.to_n}`
    RUBY

    assert_equal [true, true, ["context", 4, 5], "prefix", true, "context"], result
  end

  def test_enumeration_supports_array_like_and_iterable_objects
    run_opal <<~RUBY
      array = JS::Proxy.new(`[1, { value: 2 }, 3]`)
      enumerator = array.each
      mapped = enumerator.map { |item| item.is_a?(JS::Proxy) ? item.value : item }
      returned = array.each { |_item| }

      array_like = JS::Proxy.new(`({ 0: "a", 1: "b", length: 2 })`)
      set = JS::Proxy.new(`new Set([4, 5])`)
      plain = JS::Proxy.new(`({ value: 1 })`)

      plain_raises = begin
        plain.each { |_item| }
        false
      rescue TypeError
        true
      end

      values = [
        enumerator.is_a?(Enumerator),
        mapped,
        returned.equal?(array),
        array_like.to_a,
        set.to_a,
        plain_raises
      ]

      `window.__result = \#{values.to_n}`
    RUBY

    assert_equal [true, [1, 2, 3], true, %w[a b], [4, 5], true], result
  end

  def test_promise_chains_are_wrapped_and_do_not_mutate_the_original_promise
    run_opal <<~RUBY
      api = JS::Proxy.new(`({
        resolve: function(value) { return Promise.resolve(value); }
      })`)

      original = api.resolve(2)
      first = original.then { |value| value + 1 }
      second = first.then { |value| `window.__chain_result = \#{value}` }
      branch = original.then { |value| value + 10 }
      branch.then { |value| `window.__branch_result = \#{value}` }

      types = [original, first, second, branch].map { |promise| promise.is_a?(JS::Promise) }
      `window.__promise_types = \#{types.to_n}`
    RUBY

    wait_until { script("return window.__chain_result === 3 && window.__branch_result === 12") }

    assert_equal [true, true, true, true], script("return window.__promise_types")
    assert_equal 3, script("return window.__chain_result")
    assert_equal 12, script("return window.__branch_result")
  end

  def test_promise_callbacks_flatten_returned_promises_and_unwrap_returned_proxies
    run_opal <<~RUBY
      api = JS::Proxy.new(`({
        resolve: function(value) { return Promise.resolve(value); }
      })`)

      api.resolve(2)
        .then { |value| api.resolve(value + 3) }
        .then { |value| `window.__flattened_result = \#{value}` }

      api.resolve(nil)
        .then { JS::Proxy.new(`({ answer: 42 })`) }
        .then do |object|
          values = [object.is_a?(JS::Proxy), object.answer]
          `window.__proxy_result = \#{values.to_n}`
        end
    RUBY

    wait_until do
      script("return window.__flattened_result === 5 && window.__proxy_result !== undefined")
    end

    assert_equal 5, script("return window.__flattened_result")
    assert_equal [true, 42], script("return window.__proxy_result")
  end

  def test_promise_catch_wraps_errors_and_remains_chainable
    run_opal <<~RUBY
      api = JS::Proxy.new(`({
        rejectWithError: function() { return Promise.reject(new Error("boom")); }
      })`)

      rejection_handler = ->(error) {
        values = [error.is_a?(JS::Proxy), error["message"]]
        `window.__caught_error = \#{values.to_n}`
        "recovered"
      }
      caught = api.reject_with_error.catch(&rejection_handler)

      recovered = caught.then { |value| `window.__recovered = \#{value}` }
      chained = recovered.finally { `window.__finally_called = true` }

      values = [caught.is_a?(JS::Promise), recovered.is_a?(JS::Promise), chained.is_a?(JS::Promise)]
      `window.__catch_types = \#{values.to_n}`
    RUBY

    wait_until do
      script("return window.__recovered === 'recovered' && window.__finally_called === true")
    end

    assert_equal [true, "boom"], script("return window.__caught_error")
    assert_equal "recovered", script("return window.__recovered")
    assert_equal [true, true, true], script("return window.__catch_types")
  end

  def test_promise_callbacks_round_trip_false_zero_empty_string_and_nil
    run_opal <<~RUBY
      api = JS::Proxy.new(`({
        resolve: function(value) { return Promise.resolve(value); }
      })`)

      false_step = api.resolve(true).then { false }
      zero_callback = ->(value) {
        `window.__false_value = \#{value}`
        0
      }
      zero_step = false_step.then(&zero_callback)

      empty_callback = ->(value) {
        `window.__zero_value = \#{value}`
        ""
      }
      empty_step = zero_step.then(&empty_callback)

      nil_callback = ->(value) {
        `window.__empty_value = \#{value}`
        nil
      }
      nil_step = empty_step.then(&nil_callback)

      done_callback = ->(value) {
        `window.__nil_value = \#{value.nil?}`
        `window.__primitive_done = true`
      }
      nil_step.then(&done_callback)
    RUBY

    wait_until { script("return window.__primitive_done === true") }

    assert_equal false, script("return window.__false_value")
    assert_equal 0, script("return window.__zero_value")
    assert_equal "", script("return window.__empty_value")
    assert_equal true, script("return window.__nil_value")
  end

  def test_document_property_setter
    run_opal <<~RUBY
      document = JS::Proxy.new(`window.document`)
      document.title = "Opal Proxy Test"
    RUBY

    assert_equal "Opal Proxy Test", @driver.title
  end

  private

  def run_opal(code)
    @driver.navigate.to(index_url)
    @driver.execute_script(compile_opal(opal_code_prepended_by(code)))
  end

  def result
    script("return window.__result")
  end

  def script(source)
    @driver.execute_script(source)
  end

  def wait_until(&)
    Selenium::WebDriver::Wait.new(timeout: 5).until(&)
  end

  def opal_code_prepended_by(code)
    <<~RUBY
      # backtick_javascript: true

      #{code}
    RUBY
  end
end
