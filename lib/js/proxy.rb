# backtick_javascript: true
# frozen_string_literal: true

require "opal"
require "native"

module JS
  # Shared conversion helpers for values crossing the Ruby/JavaScript boundary.
  module Helpers
    def wrap_result(result)
      return nil if `result == null`

      if `typeof result.then === "function" && !result.then.$$owner`
        Promise.new(result)
      elsif `result instanceof Number || result instanceof String || result instanceof Boolean`
        `result.valueOf()`
      elsif `typeof result === "object"`
        Proxy.new(result)
      else
        result
      end
    end

    def native_methods
      %x{
        let object = #{to_n};
        const properties = new Set();

        while (object !== null) {
          for (const key of Reflect.ownKeys(object)) {
            if (typeof key === "symbol") continue;

            const nativeName = key.toString();
            const rubyName = #{to_rb_name(`nativeName`)};

            properties.add(nativeName);
            properties.add(rubyName);
          }
          object = Object.getPrototypeOf(object);
        }

        return Array.from(properties);
      }
    end

    private

    def unwrap_result(result)
      Native.try_convert(result, result)
    end
  end

  # Provides Ruby-style access to the properties and methods of a JavaScript object.
  class Proxy
    include Enumerable
    include Helpers

    IRREGULARS = %w[html url uri].freeze

    def initialize(native)
      self.native = native
    end

    def native
      Native(to_n)
    end

    def native=(value)
      @native = Native.try_convert(value, value)
    end

    def method_missing(name, *args, &block)
      setter = name.end_with?("=")
      property = resolve_property_name(name, allow_missing: setter)

      return super unless property
      return write_property(property, args.first) if setter

      read_property(property, args, block)
    end

    def respond_to_missing?(name, include_private = false)
      setter = name.end_with?("=")
      !!resolve_property_name(name, allow_missing: setter) || super
    end

    def each(&block)
      return enum_for(:each) unless block

      if iterable?
        each_iterable(&block)
      elsif array_like?
        each_array_like(&block)
      else
        raise TypeError, "#{self.class} does not wrap an iterable or array-like object"
      end

      self
    end

    def [](index)
      wrap_result(`#{to_n}[#{index}]`)
    end

    def []=(key, value)
      converted = unwrap_result(value)
      `#{to_n}[#{key}] = #{converted}`
      value
    end

    def to_n
      @native
    end

    def to_str
      `String(#{to_n})`
    end

    def length
      `#{to_n}.length`
    end

    private

    def read_property(property, args, block)
      value = `#{to_n}[#{property}]`
      return wrap_result(value) unless `typeof value === "function"`

      invoke_native_function(value, args, block)
    end

    def write_property(property, value)
      converted = unwrap_result(value)
      `#{to_n}[#{property}] = #{converted}`
      value
    end

    def invoke_native_function(callable, args, block)
      arguments = args.dup
      arguments << callback_for(block) if block
      wrap_result(`callable.apply(#{to_n}, #{arguments.to_n})`)
    end

    def callback_for(block)
      %x{
        return function() {
          const callbackArgs = Array.prototype.slice.call(arguments).map(function(argument) {
            return #{wrap_result(`argument`)};
          });
          const receiver = #{wrap_result(`this`)};
          return #{unwrap_result(block.call(`receiver`, *`callbackArgs`))};
        };
      }
    end

    def resolve_property_name(name, allow_missing: false)
      ruby_name = name.to_s.delete_suffix("=")
      candidates = js_name_candidates(ruby_name)
      candidates.find { |candidate| existing_property?(candidate) } ||
        (candidates.last if allow_missing)
    end

    def js_name_candidates(name)
      [name, camelize(name), camelize(name, acronyms: true)].uniq
    end

    def camelize(name, acronyms: false)
      name.split("_").map.with_index do |part, index|
        if acronyms && IRREGULARS.include?(part.downcase)
          part.upcase
        else
          index.zero? ? part : part.capitalize
        end
      end.join
    end

    def to_rb_name(name)
      name
        .to_s
        .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
        .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
        .tr("-", "_")
        .downcase
    end

    def existing_property?(property)
      `#{property} in #{to_n}`
    end

    def iterable?
      `typeof Symbol !== "undefined" && typeof #{to_n}[Symbol.iterator] === "function"`
    end

    def array_like?
      %x{
        const length = #{to_n}.length;
        return typeof length === "number" &&
          Number.isFinite(length) &&
          length >= 0 &&
          Math.floor(length) === length;
      }
    end

    def each_iterable
      iterator = `#{to_n}[Symbol.iterator]()`

      loop do
        step = `iterator.next()`
        break if `step.done`

        yield wrap_result(`step.value`)
      end
    end

    def each_array_like
      (0...length).each { |index| yield self[index] }
    end
  end

  # Ruby wrapper for JavaScript promises with chain-preserving return values.
  class Promise < Proxy
    def then(&block)
      result = block ? `#{to_n}.then(#{promise_callback(block)})` : `#{to_n}.then()`
      Promise.new(result)
    end

    def catch(&block)
      result = block ? `#{to_n}.catch(#{promise_callback(block)})` : `#{to_n}.catch()`
      Promise.new(result)
    end

    private

    def promise_callback(block)
      %x{
        const proxy = #{self};

        return function(value) {
          const wrappedValue = proxy.$wrap_result(value);
          const rubyResult = block.$call(wrappedValue);
          return proxy.$unwrap_result(rubyResult);
        };
      }
    end
  end
end
