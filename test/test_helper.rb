# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "opal_proxy"

require "opal"
Opal.append_path File.expand_path("../lib", __dir__)

require "minitest/autorun"
