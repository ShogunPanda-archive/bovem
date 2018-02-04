# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

module Bovem
  # Extension of Lazier::I18n to support method based access.
  class I18n < ::Lazier::I18n
    private

    def method_missing(method, *args)
      rv = send(:t, method)
      rv = sprintf(rv, *args) if rv.index(/%([\d.]*)[sdf]/) && args.present?
      rv
    end
  end
end
