# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "logger"
require "open4"
require "find"
require "fileutils"
require "lazier"

Lazier.load!(:object, :boolean, :math)

require "bovem/version" if !defined?(Bovem::Version)
require "bovem/errors"
require "bovem/configuration"
require "bovem/logger"
require "bovem/console"
require "bovem/shell"