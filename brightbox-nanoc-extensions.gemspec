# -*- encoding: utf-8 -*-
require File.expand_path('../lib/brightbox-nanoc-extensions/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Caius Durling"]
  gem.email         = ["hello@brightbox.co.uk"]
  gem.description   = %q{Collection of extensions for nanoc}
  gem.summary       = %q{Brightbox has written some extensions for nanoc, this gem contains them.}
  gem.homepage      = "http://github.com/brightbox/brightbox-nanoc-extensions"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "brightbox-nanoc-extensions"
  gem.require_paths = ["lib"]
  gem.version       = Brightbox::NanocExtensions::VERSION
end
