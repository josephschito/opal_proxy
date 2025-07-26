# frozen_string_literal: true

require_relative "lib/opal_proxy/version"

Gem::Specification.new do |spec|
  spec.name = "opal_proxy"
  spec.version = OpalProxy::VERSION
  spec.authors = ["Joseph Schito"]
  spec.email = ["joseph.schito@gmail.com"]

  spec.summary = "Dynamic Ruby-style wrapper for JavaScript objects in Opal."
  spec.description = "Opal Proxy provides a dynamic interface to JavaScript objects in Opal, allowing seamless property access, method calls, and Promise handling using idiomatic Ruby syntax."
  spec.homepage = "https://github.com/josephschito/opal_proxy"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/josephschito/opal_proxy"
  spec.metadata["changelog_uri"] = "https://github.com/josephschito/opal_proxy/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html

  spec.add_dependency "opal", "~> 1.8.2"
end
