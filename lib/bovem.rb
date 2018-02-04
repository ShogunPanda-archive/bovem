# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "optparse"
require "prettyprint"
require "logger"
require "open4"
require "find"
require "lazier"

Lazier.load!(:object, :boolean, :math)

require "bovem/version" unless defined?(Bovem::Version)
require "bovem/i18n"
require "bovem/errors"
require "bovem/configuration"
require "bovem/logger"
require "bovem/console"
require "bovem/shell"
require "bovem/command"
require "bovem/option"
require "bovem/application"
require "bovem/parser"
