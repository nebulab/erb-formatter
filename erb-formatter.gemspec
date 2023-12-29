# frozen_string_literal: true

require_relative "lib/erb/formatter/version"

Gem::Specification.new do |spec|
  spec.name = "erb-formatter"
  spec.version = ERB::Formatter::VERSION
  spec.authors = ["Elia Schito"]
  spec.email = ["elia@schito.me"]

  spec.summary = "Format ERB files with speed and precision."
  spec.homepage = "https://github.com/nebulab/erb-formatter#readme"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/nebulab/erb-formatter"
  spec.metadata["changelog_uri"] = "https://github.com/nebulab/erb-formatter/releases"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "syntax_tree", '~> 6.0'

  spec.add_development_dependency "tailwindcss-rails", "~> 2.0"
  spec.add_development_dependency "m", "~> 1.0"
end
