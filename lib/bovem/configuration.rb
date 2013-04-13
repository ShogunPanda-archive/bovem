# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # This class holds the configuration of an application.
  #
  # Extend this class and add valid properties via {property property} method.
  # Example:
  #
  # ```ruby
  # class MyConfiguration << Bovem::Configuration
  #   property :property, :default => "VALUE"
  # end
  #
  # # Configuration file
  # config.property = "VALUE"
  # ```
  class Configuration
    include Lazier::I18n

    # Creates a new configuration.
    #
    # A configuration file is a plain Ruby file with a top-level {Configuration config} object.
    #
    # @param file [String] The file to read.
    # @param overrides [Hash] A set of values which override those set in the configuration file.
    # @param logger [Logger] The logger to use for notifications.
    # @see #parse
    def initialize(file = nil, overrides = {}, logger = nil)
      self.i18n_setup(:bovem, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"))
      self.parse(file, overrides, logger)
    end

    # Parses a configuration file.
    #
    # A configuration file is a plain Ruby file with a top-level {Configuration config} object.
    #
    # Example:
    #
    # ```ruby
    # config.property = "VALUE"
    # ```
    #
    # @param file [String] The file to read.
    # @param logger [Logger] The logger to use for notifications.
    # @param overrides [Hash] A set of values which override those set in the configuration file.
    def parse(file = nil, overrides = {}, logger = nil)
      file = file.present? ? File.expand_path(file) : nil

      if file then
        if File.readable?(file) then
          read_configuration_file(file, logger)
        else
          raise Bovem::Errors::InvalidConfiguration.new(self.i18n.configuration.not_found(file))
        end
      end

      # Apply overrides
      if overrides.is_a?(::Hash) then
        overrides.each_pair do |k, v|
          self.send("#{k}=", v) if self.respond_to?("#{k}=")
        end
      end

      self
    end

    # Defines a new property for the configuration.
    #
    # @param name [Symbol] The name of the property.
    # @param options [Hash] A set of options for the property. Currently, only `:default` (which holds the default value) is supported.
    def self.property(name, options = {})
      options = {} if !options.is_a?(::Hash)

      define_method(name.to_s) do
        self.instance_variable_get("@#{name}") || options[:default]
      end

      define_method("#{name}=") do |value|
        self.instance_variable_set("@#{name}", value)
      end
    end

    private
      # Reads a configuration file.
      #
      # @param file [String] The file to read.
      # @param logger [Logger] The logger to use for notifications.
      def read_configuration_file(file, logger)
        begin
          # Open the file
          path = file =~ /^#{File::SEPARATOR}/ ? file : ::Pathname.new(file).realpath.to_s
          logger.info(self.i18n.configuration.using(path)) if logger
          eval_file(path)
        rescue Exception
          raise Bovem::Errors::InvalidConfiguration.new(self.i18n.configuration.invalid(file))
        end
      end

      # Eval a configuration file.
      #
      # @param path [String] The file to read.
      def eval_file(path)
        self.tap do |config|
          eval(::File.read(path))
        end
      end
  end
end