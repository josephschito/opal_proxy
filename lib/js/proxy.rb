require "opal"
require "native"

module JS
  module Helpers
    def wrap_result(result)
      if `result && typeof result.then === 'function'`
        Promise.new(result)
      elsif `typeof result === 'object' && result !== null`
        Proxy.new(result)
      else
        result
      end
    end

    def native_methods
      @native_methods ||= %x{
        let obj = #{to_n};
        const props = new Set();

        while (obj !== null) {
          for (const key of Reflect.ownKeys(obj)) {
            const stringKey = key.toString()
            const rubyName = #{to_rb_name(`stringKey`)}

            if (typeof key !== 'symbol' && stringKey !== rubyName ) { props.add(rubyName); }
            props.add(stringKey);
          }
          obj = Object.getPrototypeOf(obj);
        }

        return Array.from(props);
      }
    end
  end

  class Proxy
    include Enumerable
    include Helpers

    attr_accessor :native

    IRREGULARS = %w(html url uri)

    def initialize(native)
      @native = Native(native)
    end

    def method_missing(name, *args, &block)
      js_name = to_js_name(name)

      unless existing_property?(js_name) || js_name.end_with?("=")
        raise NoMethodError, "undefined method `#{name}` for #{self}"
      end

      if js_name.end_with?("=")
        prop = js_name[0..-2]
        native[prop] = args.first
      else
        val = native[js_name]

        if `typeof val === 'function'`
          js_args = args.dup

          if block
            js_callback = %x{
              function() {
                let args = Array.prototype.slice.call(arguments);
                return #{block.call(self.class.new(`this`), *args)};
              }
            }
            js_args << js_callback
          end

          result = `val.apply(#{to_n}, #{js_args.to_n})`
          wrap_result(result)
        elsif `typeof val === 'object' && val !== null`
          wrap_result(val)
        else
          val
        end
      end
    end

    def to_str
      `#{to_n}.toString()`
    end

    def respond_to_missing?(name, include_private = false)
      true
    end

    def each
      return enum_for(:each) unless respond_to?(:length)

      length = self.length
      (0...length).each do |i|
        yield self[i]
      end
    end

    def [](index)
      val = native[index]
      wrap_result(val)
    end

    def to_n
      native.to_n
    end

    def length
      native.length
    end

    private

    def to_js_name(name)
      name.to_s.split('_').map.with_index do |part, index|
        if IRREGULARS.include? part.gsub("=", "").downcase
          part.upcase
        else
          index.zero? ? part : part.capitalize
        end
      end.join
    end

    def to_rb_name(name)
      name
        .to_s
        .gsub(/([A-Z]+)/) { "_#{$1.downcase}" }
        .sub(/^_/, '')
    end

    def existing_property?(property)
      `#{property} in #{to_n}`
    end
  end

  class Promise < Proxy
    include Helpers

    def then(&block)
      js_callback = %x{
        function(value) {
          var ruby_result = #{block.call(wrap_result(`value`))};
          if (ruby_result && typeof ruby_result.then === 'function') {
            return ruby_result;
          } else if (ruby_result && typeof ruby_result.to_n === 'function') {
            return ruby_result.to_n();
          } else {
            return ruby_result;
          }
        }
      }

      self.native = `#{to_n}.then(#{js_callback})`
    end

    def catch(&block)
      js_callback = %x{
        function(error) {
          var ruby_result = #{block.call(wrap_result(`error`))};

          if (ruby_result && typeof ruby_result.then === 'function') {
            return ruby_result;
          } else if (ruby_result && typeof ruby_result.to_n === 'function') {
            return ruby_result.to_n();
          } else {
            return ruby_result;
          }
        }
      }

      self.native = `#{to_n}.catch(#{js_callback})`
    end
  end
end
