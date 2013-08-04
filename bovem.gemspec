# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "./lib/bovem/version"

Gem::Specification.new do |gem|
  gem.name = "bovem"
  gem.version = Bovem::Version::STRING
  gem.authors = ["Shogun"]
  gem.email = ["shogun@cowtech.it"]
  gem.homepage = "http://sw.cow.tc/bovem"
  gem.summary = %q{A command line manager and a collection of utilities for developers.}
  gem.description = %q{A command line manager and a collection of utilities for developers.}

  gem.rubyforge_project = "bovem"
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.required_ruby_version = ">= 1.9.3"

  gem.add_dependency("lazier", "~> 3.3.5")
  gem.add_dependency("open4", "~> 1.3.0")
end
