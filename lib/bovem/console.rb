# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # List of valid terminal colors.
  TERM_COLORS = { black: 0, red: 1, green: 2, yellow: 3, blue: 4, magenta: 5,  cyan: 6, white: 7, default: 9}

  # List of valid terminal text effects.
  TERM_EFFECTS = { reset: 0, bright: 1, italic: 3, underline: 4, blink: 5, inverse: 7, hide: 8 }

  # Methods of the {Console Console} class.
  module ConsoleMethods
    # Methods for handling styles in the terminal.
    module StyleHandling
      extend ActiveSupport::Concern

      # Class methods for handling styles in the terminal.
      module ClassMethods
        # Parse a style and returns terminal codes.
        #
        # Supported styles and colors are those in {Bovem::TERM\_COLORS} and {Bovem::TERM\_EFFECTS}. You can also prefix colors with `bg_` (like `bg_red`) for background colors.
        #
        # @param style [String] The style to parse.
        # @return [String] A string with ANSI color codes.
        def parse_style(style)
          style = style.ensure_string.strip.parameterize

          if style.present? then
            sym = style.to_sym

            ::Bovem::Console.replace_term_code(Bovem::TERM_EFFECTS, style, 0) ||
              ::Bovem::Console.replace_term_code(Bovem::TERM_COLORS, style, 30) ||
              ::Bovem::Console.replace_term_code(Bovem::TERM_COLORS, style.gsub(/^bg_/, ""), 40) ||
              ""
          else
            ""
          end
        end

        # Parses a set of styles and returns terminals codes.
        # Supported styles and colors are those in {Bovem::TERM\_COLORS} and {Bovem::TERM\_EFFECTS}. You can also prefix colors with `bg_` (like `bg_red`) for background colors.
        #
        # @param styles [String] The styles to parse.
        # @return [String] A string with ANSI color codes.
        def parse_styles(styles)
          styles.split(/\s*[\s,-]\s*/).collect { |s| self.parse_style(s) }.join("")
        end

        #
        # Replaces a terminal code.
        #
        # @param codes [Array] The valid list of codes.
        # @param code [String] The code to lookup.
        # @param modifier [Fixnum] The modifier to apply to the code.
        # @return [String|nil] The terminal code or `nil` if the code was not found.
        def replace_term_code(codes, code, modifier = 0)
          sym = code.to_sym
          codes.include?(sym) ? "\e[#{modifier + codes[sym]}m" : nil
        end

        # Replaces colors markers in a string.
        #
        # You can specify markers by enclosing in `{mark=[style]}` and `{/mark}` tags. Separate styles with spaces, dashes or commas. Nesting markers is supported.
        #
        # Example:
        #
        # ```ruby
        # Bovem::Console.new.replace_markers("{mark=bright bg_red}{mark=green}Hello world!{/mark}{/mark}")
        # # => "\e[1m\e[41m\e[32mHello world!\e[1m\e[41m\e[0m"
        # ```
        #
        # @param message [String] The message to analyze.
        # @param plain [Boolean] If ignore (cleanify) color markers into the message.
        # @return [String] The replaced message.
        # @see #parse_style
        def replace_markers(message, plain = false)
          stack = []

          message.ensure_string.gsub(/((\{mark=([a-z\-_\s,]+)\})|(\{\/mark\}))/mi) do
            if $1 == "{/mark}" then # If it is a tag, pop from the latest opened.
              stack.pop
              plain || stack.blank? ? "" : ::Bovem::Console.parse_styles(stack.last)
            else
              styles = $3
              replacement = plain ? "" : ::Bovem::Console.parse_styles(styles)

              if replacement.length > 0 then
                stack << "reset" if stack.blank?
                stack << styles
              end

              replacement
            end
          end
        end
      end

      # Replaces colors markers in a string.
      #
      # @see .replace_markers
      #
      # @param message [String] The message to analyze.
      # @param plain [Boolean] If ignore (cleanify) color markers into the message.
      # @return [String] The replaced message.
      def replace_markers(message, plain = false)
        ::Bovem::Console.replace_markers(message, plain)
      end
    end

    # Methods for formatting output messages.
    module Output
      # Gets the current screen width.
      #
      # @return [Fixnum] The screen width.
      def get_screen_width
        ::Bovem::Console.execute("tput cols").to_integer(80)
      end

      # Sets the new indentation width.
      #
      # @param width [Fixnum] The new width.
      # @param is_absolute [Boolean] If the new width should not be added to the current one but rather replace it.
      # @return [Fixnum] The new indentation width.
      def set_indentation(width, is_absolute = false)
        @indentation = [(!is_absolute ? @indentation : 0) + width, 0].max.to_i
        @indentation
      end

      # Resets indentation width to `0`.
      #
      # @return [Fixnum] The new indentation width.
      def reset_indentation
        @indentation = 0
      end

      # Starts a indented region of text.
      #
      # @param width [Fixnum] The new width.
      # @param is_absolute [Boolean] If the new width should not be added to the current one but rather replace it.
      # @return [Fixnum] The new indentation width.
      def with_indentation(width = 3, is_absolute = false)
        old = @indentation
        self.set_indentation(width, is_absolute)
        yield
        self.set_indentation(old, true)

        @indentation
      end

      # Wraps a message in fixed line width.
      #
      # @param message [String] The message to wrap.
      # @param width [Fixnum] The maximum width of a line. Default to the current line width.
      # @return [String] The wrapped message.
      def wrap(message, width = nil)
        if width.to_integer <= 0 then
          message
        else
          width = (width == true || width.to_integer < 0 ? self.get_screen_width : width.to_integer)

          message.split("\n").collect { |line|
            line.length > width ? line.gsub(/(.{1,#{width}})(\s+|$)/, "\\1\n").strip : line
          }.join("\n")
        end
      end

      # Indents a message.
      #
      # @param message [String] The message to indent.
      # @param width [Fixnum] The indentation width. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces. `nil` or `false` will skip indentation.
      # @param newline_separator [String] The character used for newlines.
      # @return [String] The indentend message.
      def indent(message, width = true, newline_separator = "\n")
        if width.to_integer != 0 then
          width = (width == true ? 0 : width.to_integer)
          width = width < 0 ? -width : @indentation + width

          message = message.split(newline_separator).collect {|line|
            (@indentation_string * width) + line
          }.join(newline_separator)
        end

        message
      end

      # Formats a message.
      #
      # You can style text by using `{mark}` and `{/mark}` syntax.
      #
      # @see #replace_markers
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @return [String] The formatted message.
      def format(message, suffix = "\n", indent = true, wrap = true, plain = false)
        rv = message

        rv = self.replace_markers(rv, plain) # Replace markers

        # Compute the real width available for the screen, if we both indent and wrap
        if wrap == true then
          wrap = @line_width

          if indent == true then
            wrap -= @indentation
          else
            indent_i = indent.to_integer
            wrap -= (indent_i > 0 ? @indentation : 0) + indent_i
          end
        end

        rv = self.wrap(rv, wrap) # Wrap
        rv = self.indent(rv, indent) # Indent

        rv += suffix.ensure_string if suffix # Add the suffix
        rv
      end

      # Formats a message to be written right-aligned.
      #
      # @param message [String] The message to format.
      # @param width [Fixnum] The screen width. If `true`, it is automatically computed.
      # @param go_up [Boolean] If go up one line before formatting.
      # @param plain [Boolean] If ignore color markers into the message.
      # @return [String] The formatted message.
      def format_right(message, width = true, go_up = true, plain = false)
        message = self.replace_markers(message, plain)

        rv = go_up ? "\e[A" : ""

        @screen_width ||= self.get_screen_width
        width = (width == true || width.to_integer < 1 ? @screen_width : width.to_integer)

        # Get padding
        padding = width - message.to_s.gsub(/(\e\[[0-9]*[a-z]?)|(\\n)/i, "").length

        # Return
        rv + "\e[0G\e[#{padding}C" + message
      end
    end

    # Methods for logging activities to the user.
    module Logging
      extend ActiveSupport::Concern

      # Class methods for logging activities to the user.
      module ClassMethods
        # Returns the minimum length of a banner, not including brackets and leading spaces.
        # @return [Fixnum] The minimum length of a banner.
        def min_banner_length
          1
        end
      end

      # Writes a message.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      # @return [String] The printed message.
      #
      # @see #format
      def write(message, suffix = "\n", indent = true, wrap = false, plain = false, print = true)
        rv = self.format(message, suffix, indent, wrap, plain)
        Kernel.puts(rv) if print
        rv
      end

      # Writes a message, aligning to a call with an empty banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      # @return [String] The printed message.
      #
      # @see #format
      def write_banner_aligned(message, suffix = "\n", indent = true, wrap = false, plain = false, print = true)
        self.write((" " * (::Bovem::Console.min_banner_length + 3)) + message.ensure_string, suffix, indent, wrap, plain, print)
      end

      # Writes a status to the output. Valid values are `:ok`, `:pass`, `:fail`, `:warn`.
      #
      # @param status [Symbol] The status to write.
      # @param plain [Boolean] If not use colors.
      # @param go_up [Boolean] If go up one line before formatting.
      # @param right [Boolean] If to print results on the right.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      # @return [Array] An dictionary with `:label` and `:color` keys for the status.
      def status(status, plain = false, go_up = true, right = true, print = true)
        statuses = {
          ok: {label: " OK ", color: "bright green"},
          pass: {label: "PASS", color: "bright cyan"},
          warn: {label: "WARN", color: "bright yellow"},
          fail: {label: "FAIL", color: "bright red"}
        }
        statuses.default = statuses[:ok]

        rv = statuses[status]

        if print then
          banner = self.get_banner(rv[:label], rv[:color])

          if right then
            Kernel.puts self.format_right(banner + " ", true, go_up, plain)
          else
            Kernel.puts self.format(banner + " ", "\n", true, true, plain)
          end
        end

        rv
      end

      # Gets a banner for the messages.
      #
      # @param label [String] The label for the banner.
      # @param base_color [String] The color for the label.
      # @param full_colored [String] If all the message should be of the label color.
      # @param bracket_color [String] The color of the brackets.
      # @param brackets [Array] An array of dimension 2 to use for brackets.
      # @return [String] The banner.
      # @see #format
      def get_banner(label, base_color, full_colored = false, bracket_color = "blue", brackets = ["[", "]"])
        label = label.rjust(Bovem::Console.min_banner_length, " ")
        brackets = brackets.ensure_array
        bracket_color = base_color if full_colored
        "{mark=%s}%s{mark=%s}%s{/mark}%s{/mark}" % [bracket_color.parameterize, brackets[0], base_color.parameterize, label, brackets[1]]
      end

      # Writes a message prepending a green banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def begin(message, suffix = "\n", indent = true, wrap = false, plain = false, indented_banner = false, full_colored = false, print = true)
        banner = self.get_banner("*", "bright green")
        message = self.indent(message, indented_banner ? 0 : indent)
        self.write(banner + " " + message, suffix, indented_banner ? indent : 0, wrap, plain, print)
      end

      # Writes a message prepending a red banner and then quits the application.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param return_code [Fixnum] The code to return to the shell.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def fatal(message, suffix = "\n", indent = true, wrap = false, plain = false, indented_banner = false, full_colored = false, return_code = -1, print = true)
        self.error(message, suffix, indent, wrap, plain, indented_banner, full_colored, print)
        Kernel.exit(return_code.to_integer(-1))
      end

      # Writes a message prepending a cyan banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      # @param banner [Array] An array with at last letter and style to use for the banner.
      #
      # @see #format
      def info(message, suffix = "\n", indent = true, wrap = false, plain = false, indented_banner = false, full_colored = false, print = true, *banner)
        banner = banner.ensure_array.flatten
        banner = ["I", "bright cyan"] if banner.blank?
        banner = self.get_banner(banner[0], banner[1], full_colored)
        message = self.indent(message, indented_banner ? 0 : indent)
        self.write(banner + " " + message, suffix, indented_banner ? indent : 0, wrap, plain, print)
      end

      # Writes a message prepending a magenta banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def debug(message, suffix = "\n", indent = true, wrap = false, plain = false, indented_banner = false, full_colored = false, print = true)
        self.info(message, suffix, indent, wrap, plain, indented_banner, full_colored, print, ["D", "bright magenta"])
      end

      # Writes a message prepending a yellow banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def warn(message, suffix = "\n", indent = true, wrap = false, plain = false, indented_banner = false, full_colored = false, print = true)
        warn_banner = ["W", "bright yellow"]
        self.info(message, suffix, indent, wrap, plain, indented_banner, full_colored, print, warn_banner)
      end

      # Writes a message prepending a red banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def error(message, suffix = "\n", indent = true, wrap = false, plain = false, indented_banner = false, full_colored = false, print = true)
        self.info(message, suffix, indent, wrap, plain, indented_banner, full_colored, print, "E", "bright red")
      end
    end

    # Methods to interact with the user and other processes.
    module Interactions
      extend ActiveSupport::Concern

      # Class methods to interact with the user and other processes.
      module ClassMethods
        # Executes a command and returns its output.
        #
        # @param command [String] The command to execute.
        # @return [String] The command's output.
        def execute(command)
          %x{#{command}}
        end
      end

      # Reads a string from the console.
      #
      # @param prompt [String|Boolean] A prompt to show. If `true`, `Please insert a value:` will be used, if `nil` or `false` no prompt will be shown.
      # @param default_value [String] Default value if user simply pressed the enter key.
      # @param validator [Array|Regexp] An array of values or a Regexp to match the submitted value against.
      # @param echo [Boolean] If to show submitted text to the user.
      def read(prompt = true, default_value = nil, validator = nil, echo = true)
        prompt = sanitize_prompt(prompt)

        # Adjust validator
        validator = sanitize_validator(validator)

        with_echo_handling(echo) do
          begin
            catch(:reply) do
              while true do
                reply = validate_input_value(read_input_value(prompt, default_value), validator)
                handle_reply(reply)
              end
            end
          rescue Interrupt => e
            default_value
          end
        end
      end

      # Executes a block of code in a indentation region and then prints out and ending status message.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indent [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation, a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param block_indentation [Fixnum] The new width for the indented region.
      # @param block_indentation_absolute [Boolean] If the new width should not be added to the current one but rather replace it.
      # @return [Symbol] The exit status for the block.
      def task(message = nil, suffix = "\n", indent = true, wrap = false, plain = false, indented_banner = false, full_colored = false, block_indentation = 2, block_indentation_absolute = false)
        status = nil

        self.begin(message, suffix, indent, wrap, plain, indented_banner, full_colored) if message.present?
        self.with_indentation(block_indentation, block_indentation_absolute) do
          rv = block_given? ? yield.ensure_array : [:ok] # Execute block
          exit_task(message, rv, plain) # Handle task exit
          status = rv[0] # Return value

        end

        status
      end

      private
        # Handles task exit.
        #
        # @param message [String] The message to format.
        # @param rv [Array] An array with exit status and exit code.
        # @param plain [Boolean] If ignore color markers into the message.
        def exit_task(message, rv, plain)
          if rv[0] == :fatal then
            self.status(:fail, plain)
            exit(rv.length > 1 ? rv[1].to_integer : -1)
          else
            self.status(rv[0], plain) if message.present?
          end
        end

        # Returns a prompt for input prompting.
        #
        # @param prompt [String]
        # @return [String|nil] The prompt to use or `nil`, if no message must be prompted.
        def sanitize_prompt(prompt)
          if prompt.present?
            (prompt == true ? self.i18n.console.prompt : prompt).gsub(/:?\s*$/, "") + ": "
          else
            nil
          end
        end

        # Make sure that the validators are an array of string if not a regexp.
        #
        # @param validator [String|Regexp] The validator to sanitize.
        # @return [Object] A list of strings, a Regexp or nil.
        def sanitize_validator(validator)
          validator.present? && !validator.is_a?(::Regexp) ? validator.ensure_array.collect {|v| v.ensure_string} : validator
        end

        # Handle terminal echoing.
        #
        # @param echo [Boolean] If disabled echoing
        def with_echo_handling(echo = true)
          rv = nil

          disable_echo = !echo && @stty.present? && /-echo\b/mix.match(::Bovem::Console.execute(@stty)).nil?
          ::Bovem::Console.execute("#{@stty} -echo") if disable_echo
          rv = yield
          ::Bovem::Console.execute("#{@stty} echo") if disable_echo

          rv
        end

        # Read an input from the terminal.
        #
        # @param prompt [String] A message to show to the user.
        # @param default_value [Object] A default value to enter if the user just pressed the enter key.
        # @return [Object] The read value.
        def read_input_value(prompt, default_value = nil)
          if prompt then
            Kernel.print self.format(prompt, false, false)
            $stdout.flush
          end

          reply = $stdin.gets.chop
          reply.present? ? reply : default_value
        end

        # Validates a read value from the terminal.
        #
        # @param reply [String] The value to validate.
        # @param validator [Array|Regexp] An array of values or a Regexp to match the submitted value against.
        # @return [String|nil] The validated value or `nil`, if the value is invalid.
        def validate_input_value(reply, validator)
          # Match against the validator
          if validator.present? then
            if validator.is_a?(Array) then
              reply = nil if validator.length > 0 && !validator.include?(reply)
            elsif validator.is_a?(Regexp) then
              reply = nil if !validator.match(reply)
            end
          end

          reply
        end

        # Handles a read value from the terminal.
        #
        # @param reply [String] The value to handle.
        def handle_reply(reply)
          if reply then
            throw(:reply, reply)
          else
            self.write(self.i18n.console.unknown_reply, false, false)
          end
        end
    end
  end

  # This is a text utility wrapper console I/O.
  #
  # @attribute line_width
  #   @return [Fixnum] The line width. Default to `80`.
  # @attribute screen_width
  #   @return [Fixnum] The current screen width.
  # @attribute indentation
  #   @return [Fixnum] Current indentation width.
  # @attribute indentation_string
  #   @return [String] The string used for indentation.
  class Console
    attr_accessor :line_width
    attr_accessor :screen_width
    attr_accessor :indentation
    attr_accessor :indentation_string

    include Lazier::I18n
    include Bovem::ConsoleMethods::StyleHandling
    include Bovem::ConsoleMethods::Output
    include Bovem::ConsoleMethods::Logging
    include Bovem::ConsoleMethods::Interactions

    # Returns a unique instance for Console.
    #
    # @return [Console] A new instance.
    def self.instance
      @instance ||= ::Bovem::Console.new
    end

    # Initializes a new Console.
    def initialize
      @line_width = self.get_screen_width
      @indentation = 0
      @indentation_string = " "
      @stty = ::Bovem::Console.execute("which stty").strip
      self.i18n_setup(:bovem, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"))
    end
  end
end