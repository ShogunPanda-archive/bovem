# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # Methods for the {Parser Parser} class.
  module ParserMethods
    # General methods.
    module General
      extend ActiveSupport::Concern

      # Class methods
      module ClassMethods
        # Joins an array using multiple separators.
        #
        # @param array [Array] The array to join.
        # @param separator [String] The separator to use for all but last join.
        # @param last_separator [String] The separator to use for the last join.
        # @param quote [String] If not nil, elements are quoted with that element.
        # @return [String] The joined array.
        def smart_join(array, separator: ", ", last_separator: " and ", quote: "\"")
          separator = separator.ensure_string
          last_separator = last_separator.ensure_string
          array = array.ensure_array { |a| quote.present? ? "#{quote}#{a}#{quote}" : a.ensure_string }
          perform_smart_join(array, last_separator, separator)
        end

        # Finds a command which corresponds to an argument.
        #
        # @param arg [String] The string to match.
        # @param command [Command] The command to search subcommand in.
        # @param args [String] The complete list of arguments passed.
        # @param separator [String] The separator for joined syntax commands.
        # @return [Hash|NilClass] An hash with `name` and `args` keys if a valid subcommand is found, `nil` otherwise.
        def find_command(arg, command, args: {}, separator: ":")
          return nil unless command.commands.present?

          arg, args = adjust_command(arg, args, separator)

          matching = match_subcommands(arg, command)
          if matching.length == 1 # Found a command
            {name: matching[0], args: args}
          elsif matching.length > 1 # Ambiguous match
            raise Bovem::Errors::Error.new(command, :ambiguous_command, command.i18n.ambigous_command(arg, format_alternatives(matching, command)))
          end
        end

        # Parses a command/application.
        #
        # @param command [Command] The command or application to parse.
        # @param args [Array] The arguments to parse.
        # @return [Hash|NilClass] An hash with `name` (of a subcommand to execute) and `args` keys if a valid subcommand is found, `nil` otherwise.
        def parse(command, args)
          Bovem::Parser.new.parse(command, args)
        end

        private

        # :nodoc:
        def adjust_command(arg, args, separator)
          args = args.ensure_array.dup

          if arg.index(separator)
            tokens = arg.split(separator, 2)
            arg = tokens[0]
            args.insert(0, tokens[1])
          end

          [arg, args]
        end

        # :nodoc:
        def match_subcommands(arg, command)
          command.commands.keys.select { |c| c =~ /^(#{Regexp.quote(arg)})/ }.compact
        end

        # :nodoc:
        def format_alternatives(matching, command)
          Bovem::Parser.smart_join(matching, ", ", command.i18n.join_separator).html_safe
        end

        # :nodoc:
        def perform_smart_join(array, last_separator, separator)
          array.length < 2 ? (array[0] || "") : (array[0, array.length - 1].join(separator) + last_separator + array[-1])
        end
      end
    end
  end

  # The parser for the command line.
  class Parser
    include Bovem::ParserMethods::General

    # Parses a command/application.
    #
    # @param command [Command] The command or application to parse.
    # @param args [Array] The arguments to parse.
    # @return [Hash|NilClass] An hash with `name` (of a subcommand to execute) and `args` keys if a valid subcommand is found, `nil` otherwise.
    def parse(command, args)
      args = args.ensure_array.dup
      forms, parser = create_parser(command)
      perform_parsing(parser, command, args, forms)
    end

    private

    # :nodoc:
    def create_parser(command)
      forms = {}
      parser = OptionParser.new do |opts|
        # Add every option
        command.options.each_pair do |_, option|
          check_unique(command, forms, option)
          setup_option(command, opts, option)
        end
      end

      [forms, parser]
    end

    # :nodoc:
    def perform_parsing(parser, command, args, forms)
      rv = nil

      begin
        rv = execute_parsing(parser, command, args)
      rescue OptionParser::NeedlessArgument, OptionParser::MissingArgument, OptionParser::InvalidOption => e
        fail_invalid_option(command, forms, e)
      rescue => e
        raise e
      end

      rv
    end

    # :nodoc:
    def fail_invalid_option(command, forms, oe)
      type = oe.class.to_s.gsub("OptionParser::", "").underscore.to_sym
      opt = oe.args.first
      raise Bovem::Errors::Error.new(forms[opt], type, command.i18n.send(type, opt))
    end

    # :nodoc:
    def execute_parsing(parser, command, args)
      rv = nil

      if command.options.present?
        rv = parse_options(parser, command, args)
        check_required_options(command)
      elsif args.present?
        rv = find_command_to_execute(command, args)
      end

      rv
    end

    # :nodoc:
    def setup_option(command, opts, option)
      case option.type.to_s
      when "String" then parse_string(command, opts, option)
      when "Integer", "Fixnum", "Bignum" then setup_int_option(command, option, opts)
      when "Float" then parse_number(command, opts, option, :is_float?, :to_float, command.i18n.invalid_float(option.label))
      when "Array" then parse_array(command, opts, option)
      else option.action.present? ? parse_action(opts, option) : parse_boolean(opts, option)
      end
    end

    # :nodoc:
    def setup_int_option(command, option, opts)
      parse_number(command, opts, option, :is_integer?, :to_integer, command.i18n.invalid_integer(option.label))
    end

    # :nodoc:
    def check_unique(command, forms, option)
      if forms[option.complete_short] || forms[option.complete_long]
        fail_non_unique_option(command, forms, option)
      else
        forms[option.complete_short] = option.dup
        forms[option.complete_long] = option.dup
      end
    end

    # :nodoc:
    def fail_non_unique_option(command, forms, option)
      raise Bovem::Errors::Error.new(command, :ambiguous_form, command.i18n.conflicting_options(option.label, forms[option.complete_short].label))
    end

    # :nodoc:
    def parse_option(command, opts, option)
      opts.on("#{option.complete_short} #{option.meta || command.i18n.help_arg}", "#{option.complete_long} #{option.meta || command.i18n.help_arg}") do |value|
        yield(value)
      end
    end

    # :nodoc:
    def parse_action(opts, option)
      opts.on("-#{option.short}", "--#{option.long}") do |_|
        option.execute_action
      end
    end

    # :nodoc:
    def parse_string(command, opts, option)
      parse_option(command, opts, option) { |value| option.set(value) }
    end

    # :nodoc:
    def parse_number(command, opts, option, check_method, convert_method, invalid_message)
      parse_option(command, opts, option) do |value|
        raise Bovem::Errors::Error.new(option, :invalid_argument, invalid_message) unless value.send(check_method)
        option.set(value.send(convert_method))
      end
    end

    # :nodoc:
    def parse_array(command, opts, option)
      meta = option.meta || command.i18n.help_arg

      opts.on("#{option.complete_short} #{meta}", "#{option.complete_long} #{meta}", Array) do |value|
        option.set(value.ensure_array)
      end
    end

    # :nodoc:
    def parse_boolean(opts, option)
      opts.on("-#{option.short}", "--#{option.long}") do |value|
        option.set(value.to_boolean)
      end
    end

    # :nodoc:
    def parse_options(parser, command, args)
      rv = nil

      # Parse options
      parser.order!(args) do |arg|
        fc = Bovem::Parser.find_command(arg, command, args)

        if fc.present?
          rv = fc
          parser.terminate
        else
          command.argument(arg)
        end
      end

      rv
    end

    # :nodoc:
    def check_required_options(command)
      # Check if any required option is missing.
      command.options.each_pair do |_, option|
        raise Bovem::Errors::Error.new(option, :missing_option, command.i18n.missing_option(option.label)) if option.required && !option.provided?
      end
    end

    # :nodoc:
    def find_command_to_execute(command, args)
      rv = nil

      # Try to find a command into the first argument
      fc = Bovem::Parser.find_command(args[0], command, args[1, args.length - 1])

      if fc.present?
        rv = fc
      else
        args.each do |arg|
          command.argument(arg)
        end
      end

      rv
    end
  end
end
