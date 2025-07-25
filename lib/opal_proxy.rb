# frozen_string_literal: true

if RUBY_ENGINE == 'opal'
  require_relative "js/proxy"
else
  require "opal"
  require_relative "opal_proxy/version"

  Opal.append_path File.expand_path('lib', __dir__)
end

module OpalProxy
end
