# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "./lib/bovem/version"

Gem::Specification.new do |gem|
  gem.name = "bovem"
  gem.version = Bovem::Version::STRING
  gem.authors = ["Shogun"]
  gem.email = ["shogun_panda@me.com"]
  gem.homepage = "http://sw.cow.tc/bovem"
  gem.summary = %q{A collection of utilities for developers.}
  gem.description = %q{A collection of utilities for developers.}

  gem.rubyforge_project = "bovem"
  gem.files = `git ls-files`.split("\n")
  gem.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.required_ruby_version = ">= 1.9.3"

  gem.add_dependency("lazier", "~> 2.6.4")
  gem.add_dependency("open4", "~> 1.3.0")
end
