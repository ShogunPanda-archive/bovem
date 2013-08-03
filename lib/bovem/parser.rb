# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
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
        def smart_join(array, separator = ", ", last_separator = " and ", quote = "\"")
          separator = separator.ensure_string
          last_separator = last_separator.ensure_string
          array = array.ensure_array {|a| quote.present? ? "#{quote}#{a}#{quote}" : a.ensure_string }
          array.length < 2 ? (array[0] || "") : (array[0, array.length - 1].join(separator) + last_separator + array[-1])
        end

        # Finds a command which corresponds to an argument.
        #
        # @param arg [String] The string to match.
        # @param command [Command] The command to search subcommand in.
        # @param args [String] The complete list of arguments passed.
        # @param separator [String] The separator for joined syntax commands.
        # @return [Hash|NilClass] An hash with `name` and `args` keys if a valid subcommand is found, `nil` otherwise.
        def find_command(arg, command, args, separator = ":")
          args = args.ensure_array.dup

          if command.commands.present? then
            arg, args = adjust_command(arg, args, separator)

            matching = match_subcommands(arg, command)
            if matching.length == 1 # Found a command
              {name: matching[0], args: args}
            elsif matching.length > 1 # Ambiguous match
              raise Bovem::Errors::Error.new(command, :ambiguous_command, command.i18n.ambigous_command(arg, Bovem::Parser.smart_join(matching).html_safe))
            end
          else
            nil
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
          # Adjusts a command so that it only specify a single command.
          #
          # @param arg [String] The string to match.
          # @param args [String] The complete list of arguments passed.
          # @param separator [String] The separator for joined syntax commands.
          # @return [Array] Adjust command and arguments.
          def adjust_command(arg, args, separator)
            if arg.index(separator) then
              tokens = arg.split(separator, 2)
              arg = tokens[0]
              args.insert(0, tokens[1])
            end

            [arg, args]
          end

          # Matches a string against a command's subcommands.
          #
          # @param arg [String] The string to match.
          # @param command [Command] The command to search subcommand in.
          # @return [Array] The matching subcommands.
          def match_subcommands(arg, command)
            command.commands.keys.select {|c| c =~ /^(#{Regexp.quote(arg)})/ }.compact
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
      # Creates a new option parser.
      #
      # @param command [Command] The command or application to parse.
      # @return [OptionParser] The new parser
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

      # Perform the parsing
      #
      # @param parser [OptionParser] The option parser.
      # @param command [Command] The command or application to parse.
      # @param args [Array] The arguments to parse.
      # @param forms [Hash] The current forms.
      def perform_parsing(parser, command, args, forms)
        rv = nil

        begin
          rv = execute_parsing(parser, command, args)
        rescue OptionParser::NeedlessArgument, OptionParser::MissingArgument, OptionParser::InvalidOption => oe
          type = oe.class.to_s.gsub("OptionParser::", "").underscore.to_sym
          opt = oe.args.first
          raise Bovem::Errors::Error.new(forms[opt], type, command.i18n.send(type, opt))
        rescue => e
          raise e
        end

        rv
      end

      # Executes the parsing.
      #
      # @param parser [OptionParser] The option parser.
      # @param command [Command] The command or application to parse.
      # @param args [Array] The arguments to parse.
      # @return [Command|nil] A command to execute or `nil` if no valid command was found.
      def execute_parsing(parser, command, args)
        rv = nil

        if command.options.present? then
          rv = parse_options(parser, command, args)
          check_required_options(command)
        elsif args.present? then
          rv = find_command_to_execute(command, args)
        end

        rv
      end

      # Setups an option for a command.
      #
      # @param command [Command] The command or application to parse.
      # @param opts [Object] The current set options.
      # @param option [Option] The option to set.
      def setup_option(command, opts, option)
        case option.type.to_s
          when "String" then parse_string(command, opts, option)
          when "Integer", "Fixnum", "Bignum" then parse_number(command, opts, option, :is_integer?, :to_integer, command.i18n.invalid_integer(option.label))
          when "Float" then parse_number(command, opts, option, :is_float?, :to_float, command.i18n.invalid_float(option.label))
          when "Array" then parse_array(command, opts, option)
          else option.action.present? ? parse_action(opts, option) : parse_boolean(opts, option)
        end
      end

      # Checks if a option is unique.
      #
      # @param command [Command] The command or application to parse.
      # @param forms [Hash] The current forms.
      # @param option [Option] The option to set.
      def check_unique(command, forms, option)
        if forms[option.complete_short] || forms[option.complete_long] then
          raise Bovem::Errors::Error.new(command, :ambiguous_form, command.i18n.conflicting_options(option.label, forms[option.complete_short].label))
        else
          forms[option.complete_short] = option.dup
          forms[option.complete_long] = option.dup
        end
      end

      # Parses an action option. A block must be provided to deal with the value.
      #
      # @param command [Command] The command or application to parse.
      # @param opts [Object] The current set options.
      # @param option [Option] The option to set.
      def parse_option(command, opts, option)
        opts.on("#{option.complete_short} #{option.meta || command.i18n.help_arg}", "#{option.complete_long} #{option.meta || command.i18n.help_arg}") do |value|
          yield(value)
        end
      end

      # Parses an action option.
      #
      # @param opts [Object] The current set options.
      # @param option [Option] The option to set.
      def parse_action(opts, option)
        opts.on("-#{option.short}", "--#{option.long}") do |_|
          option.execute_action
        end
      end

      # Parses a string option.
      #
      # @param command [Command] The command or application to parse.
      # @param opts [Object] The current set options.
      # @param option [Option] The option to set.
      def parse_string(command, opts, option)
        parse_option(command, opts, option) { |value| option.set(value) }
      end

      # Parses a number option.
      #
      # @param command [Command] The command or application to parse.
      # @param opts [Object] The current set options.
      # @param option [Option] The option to set.
      # @param check_method [Symbol] The method to execute to check option validity. Must return a boolean.
      # @param convert_method [Symbol] The method to execute to convert option.
      # @param invalid_message [String] The string to send in case of invalid arguments.
      def parse_number(command, opts, option, check_method, convert_method, invalid_message)
        parse_option(command, opts, option) do |value|
          raise Bovem::Errors::Error.new(option, :invalid_argument, invalid_message) if !value.send(check_method)
          option.set(value.send(convert_method))
        end
      end

      # Parses an array option.
      #
      # @param command [Command] The command or application to parse.
      # @param opts [Object] The current set options.
      # @param option [Option] The option to set.
      def parse_array(command, opts, option)
        opts.on("#{option.complete_short} #{option.meta || command.i18n.help_arg}", "#{option.complete_long} #{option.meta || command.i18n.help_arg}", Array) do |value|
          option.set(value.ensure_array)
        end
      end

      # Parses an action option.
      #
      # @param opts [Object] The current set options.
      # @param option [Option] The option to set.
      def parse_boolean(opts, option)
        opts.on("-#{option.short}", "--#{option.long}") do |value|
          option.set(value.to_boolean)
        end
      end

      # Parses options of a command.
      #
      # @param parser [OptionParser] The option parser.
      # @param command [Command] The command or application to parse.
      # @param args [Array] The arguments to parse.
      # @return [Command|nil] A command to execute or `nil` if no command was found.
      def parse_options(parser, command, args)
        rv = nil

        # Parse options
        parser.order!(args) do |arg|
          fc = Bovem::Parser.find_command(arg, command, args)

          if fc.present? then
            rv = fc
            parser.terminate
          else
            command.argument(arg)
          end
        end

        rv
      end

      # Checks if all options of a command are present.
      #
      # @param command [Command] The command or application to parse.
      def check_required_options(command)
        # Check if any required option is missing.
        command.options.each_pair  do |name, option|
          raise Bovem::Errors::Error.new(option, :missing_option, command.i18n.missing_option(option.label)) if option.required && !option.provided?
        end
      end

      # Finds a command to execute
      #
      # @param command [Command] The command or application to parse.
      # @param args [Array] The arguments to parse.
      # @return [Command|nil] A command to execute or `nil` if no command was found.
      def find_command_to_execute(command, args)
        rv = nil

        # Try to find a command into the first argument
        fc = Bovem::Parser.find_command(args[0], command, args[1, args.length - 1])

        if fc.present? then
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