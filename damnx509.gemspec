# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'damnx509/version'

Gem::Specification.new do |spec|
  spec.name          = "damnx509"
  spec.version       = Damnx509::VERSION
  spec.authors       = ["Greg V"]
  spec.email         = ["greg@unrelenting.technology"]

  spec.summary       = %q{Easy interactive CLI for managing a small X.509 (TLS) Certificate Authority}
  spec.homepage      = "https://github.com/myfreeweb/damnx509"
  spec.license       = "Unlicense"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 0.19"
  spec.add_dependency "highline", "~> 1.7"
  spec.add_dependency "chronic_duration", "~> 0.10"
  spec.add_dependency "r509", "~> 1.0"
  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
end
