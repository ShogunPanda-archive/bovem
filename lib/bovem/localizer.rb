# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # This class is used to localize strings inside classes methods.
  class Localizer < ::Lazier::Localizer
    # Initialize a new localizer.
    #
    # @param locale [String|Symbol] The locale to use for localization.
    def initialize(locale)
      super("bovem.application", ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"), locale)
    end

    # Localize a message in a specified locale.
    #
    # @param locale [String|Symbol] The locale to use for localization.
    # @param message [String|Symbol] The message to localize.
    # @param args [Array] Optional arguments to localize the message.
    # @return [String|R18n::Untranslated] The localized message.
    def self.localize_on_locale(locale, message, *args)
      new(locale).i18n.send(message, *args)
    end
  end
end