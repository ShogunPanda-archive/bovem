# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # Exceptions for {Bovem Bovem}.
  module Errors
    # This exception is raised if a {Configuration Configuration} is invalid.
    class InvalidConfiguration < ::ArgumentError
    end

    # This exception is raised if a {Logger Logger} is invalid.
    class InvalidLogger < ::ArgumentError
    end
  end
end