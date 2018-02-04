# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

# A mapion of utilities for developers.
module Bovem
  # The current version of bovem, according to semantic versioning.
  #
  # @see http://semver.org
  module Version
    # The major version.
    MAJOR = 4

    # The minor version.
    MINOR = 0

    # The patch version.
    PATCH = 1

    # The current version number of Bovem.
    STRING = [MAJOR, MINOR, PATCH].compact.join(".")
  end
end
