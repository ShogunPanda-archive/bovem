# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # List of valid terminal colors.
  TERM_COLORS = {black: 0, red: 1, green: 2, yellow: 3, blue: 4, magenta: 5, cyan: 6, white: 7, default: 9}.freeze

  # List of valid terminal text effects.
  TERM_EFFECTS = {reset: 0, bright: 1, italic: 3, underline: 4, blink: 5, inverse: 7, hide: 8}.freeze

  # Methods of the {Console Console} class.
  module ConsoleMethods
    # Methods for handling styles in the terminal.
    module StyleHandling
      extend ActiveSupport::Concern

      # Class methods for handling styles in the terminal.
      module ClassMethods
        # Parse a style and returns terminal codes.
        #
        # Supported styles and colors are those in {Bovem::TERM\_COLORS} and {Bovem::TERM\_EFFECTS}.
        #   You can also prefix colors with `bg_` (like `bg_red`) for background colors.
        #
        # @param style [String] The style to parse.
        # @return [String] A string with ANSI color codes.
        def parse_style(style)
          style = style.ensure_string.strip.parameterize

          if style.present?
            Bovem::Console.replace_term_code(Bovem::TERM_EFFECTS, style, 0) ||
              Bovem::Console.replace_term_code(Bovem::TERM_COLORS, style, 30) ||
              Bovem::Console.replace_term_code(Bovem::TERM_COLORS, style.gsub(/^bg_/, ""), 40) ||
              ""
          else
            ""
          end
        end

        # Parses a set of styles and returns terminals codes.
        # Supported styles and colors are those in {Bovem::TERM\_COLORS} and {Bovem::TERM\_EFFECTS}.
        #   You can also prefix colors with `bg_` (like `bg_red`) for background colors.
        #
        # @param styles [String] The styles to parse.
        # @return [String] A string with ANSI color codes.
        def parse_styles(styles)
          styles.split(/\s*[\s,-]\s*/).map { |s| parse_style(s) }.join("")
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
        # You can specify markers by enclosing in `{mark=[style]}` and `{/mark}` tags.
        #   Separate styles with spaces, dashes or commas. Nesting markers is supported.
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
            if $LAST_MATCH_INFO[1] == "{/mark}" # If it is a tag, pop from the latest opened.
              stack.pop
              plain || stack.blank? ? "" : Bovem::Console.parse_styles(stack.last)
            else
              add_style($LAST_MATCH_INFO[3], plain, stack)
            end
          end
        end

        private

        # :nodoc:
        def add_style(styles, plain, stack)
          styles = styles.ensure_string
          replacement = plain ? "" : Bovem::Console.parse_styles(styles)

          unless replacement.empty?
            stack << "reset" if stack.blank?
            stack << styles
          end

          replacement
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
        Bovem::Console.replace_markers(message, plain)
      end
    end

    # Methods for formatting output messages.
    module Output
      # Sets the new indentation width.
      #
      # @param width [Fixnum] The new width.
      # @param is_absolute [Boolean] If the new width should not be added to the current one but rather replace it.
      # @return [Fixnum] The new indentation width.
      def set_indentation(width, is_absolute = false)
        @indentation = [(!is_absolute ? @indentation : 0) + width, 0].max.to_i
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
        set_indentation(width, is_absolute)
        yield
        set_indentation(old, true)

        @indentation
      end

      # Wraps a message in fixed line width.
      #
      # @param message [String] The message to wrap.
      # @param width [Fixnum] The maximum width of a line. Default to the current line width.
      # @return [String] The wrapped message.
      def wrap(message, width = nil)
        if width.to_integer <= 0
          message
        else
          width = (width == true || width.to_integer < 0 ? line_width : width.to_integer)

          rv = message.split("\n").map do |line|
            wrap_line(line, width)
          end

          rv.join("\n")
        end
      end

      # Indents a message.
      #
      # @param message [String] The message to indent.
      # @param width [Fixnum] The indentation width. `true` means to use the current indentation, a negative value of `-x`
      #   will indent of `x` absolute spaces. `nil` or `false` will skip indentation.
      # @param newline_separator [String] The character used for newlines.
      # @return [String] The indented message.
      def indent(message, width = true, newline_separator = "\n")
        if width.to_integer != 0
          width = (width.is_a?(TrueClass) ? 0 : width.to_integer)
          width = width < 0 ? -width : @indentation + width

          rv = message.split(newline_separator).map do |line|
            (@indentation_string * width) + line
          end

          message = rv.join(newline_separator)
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
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @return [String] The formatted message.
      def format(message, suffix: "\n", indented: true, wrap: true, plain: false)
        rv = message

        rv = replace_markers(rv, plain) # Replace markers

        # Compute the real width available for the screen, if we both indent and wrap
        wrap = compute_wrap(indented) if wrap.is_a?(TrueClass)

        rv = indent(wrap(rv, wrap), indented) # Wrap & Indent
        rv += (suffix.is_a?(TrueClass) ? "\n" : suffix.ensure_string) if suffix # Add the suffix
        rv
      end

      # Formats a message to be written right-aligned.
      #
      # @param message [String] The message to format.
      # @param width [Fixnum] The screen width. If `true`, it is automatically computed.
      # @param go_up [Boolean] If go up one line before formatting.
      # @param plain [Boolean] If ignore color markers into the message.
      # @return [String] The formatted message.
      def format_right(message, width: true, go_up: true, plain: false)
        message = replace_markers(message, plain)

        width = (width == true || width.to_integer < 1 ? line_width : to_integer)

        # Get padding
        padding = width - message.to_s.gsub(/(\e\[[0-9]*[a-z]?)|(\\n)/i, "").length

        # Return
        "#{go_up ? "\e[A" : ""}\e[0G\e[#{padding}C#{message}"
      end

      # Embeds a message in a style.
      #
      # @param message [String] The message to emphasize.
      # @param style [String] The style to use.
      # @return [String] The emphasized message.
      def emphasize(message, style = "bright")
        "{mark=#{style}}#{message}{/mark}"
      end

      private

      # :nodoc:
      def wrap_line(line, width)
        line.length > width ? line.gsub(/(\S{1,#{width}})(\s+|$)/, "\\1\n#{@indentation_string * @indentation}").rstrip : line
      end

      # :nodoc:
      def compute_wrap(indent)
        wrap = line_width

        if indent.is_a?(TrueClass)
          wrap -= @indentation
        else
          indent_i = indent.to_integer
          wrap -= (indent_i > 0 ? @indentation : 0) + indent_i
        end
        wrap
      end
    end

    # Methods for logging activities to the user.
    module Logging
      extend ActiveSupport::Concern

      # Available statuses for tasks.
      DEFAULT_STATUSES = {
        ok: {label: " OK ", color: "bright green"},
        pass: {label: "PASS", color: "bright cyan"},
        warn: {label: "WARN", color: "bright yellow"},
        fail: {label: "FAIL", color: "bright red"},
        skip: {label: "SKIP", color: "gray"}
      }.freeze

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
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      # @return [String] The printed message.
      #
      # @see #format
      def write(message, suffix: "\n", indented: true, wrap: false, plain: false, print: true)
        rv = format(message, suffix: suffix, indented: indented, wrap: wrap, plain: plain)
        Kernel.puts(rv) if print
        rv
      end

      # Writes a message, aligning to a call with an empty banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      # @return [String] The printed message.
      #
      # @see #format
      def write_banner_aligned(message, suffix: "\n", indented: true, wrap: false, plain: false, print: true)
        write(
          (" " * (Bovem::Console.min_banner_length + 3)) + message.ensure_string,
          suffix: suffix,
          indented: indented,
          wrap: wrap,
          plain: plain,
          print: print
        )
      end

      # Writes a status to the output. Valid values are `:ok`, `:pass`, `:fail`, `:warn`, `skip`.
      #
      # @param status [Symbol] The status to write.
      # @param plain [Boolean] If not use colors.
      # @param go_up [Boolean] If go up one line before formatting.
      # @param right [Boolean] If to print results on the right.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      # @return [Array] An dictionary with `:label` and `:color` keys for the status.
      def status(status, plain: false, go_up: true, right: true, print: true)
        statuses = DEFAULT_STATUSES.dup
        statuses.default = statuses[:ok]

        rv = statuses[status]

        if print
          banner = get_banner(rv[:label], rv[:color])

          if right
            Kernel.puts(format_right(banner + " ", width: true, go_up: go_up, plain: plain))
          else
            Kernel.puts(format(banner + " ", suffix: "\n", indent: true, wrap: true, plain: plain))
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
      def get_banner(label, base_color, full_colored: false, bracket_color: "blue", brackets: ["[", "]"])
        label = label.rjust(Bovem::Console.min_banner_length, " ")
        brackets = brackets.ensure_array
        bracket_color = base_color if full_colored
        sprintf("{mark=%s}%s{mark=%s}%s{/mark}%s{/mark}", bracket_color.parameterize, brackets[0], base_color.parameterize, label, brackets[1])
      end

      # Formats a progress for pretty printing.
      #
      # @param current [Fixnum] The current progress index (e.g. the number of the current operation).
      # @param total [Fixnum] The total progress index (e.g. the total number of operations).
      # @param type [Symbol] The progress type. Can be `:list` (e.g. 01/15) or `:percentage` (e.g. 99.56%).
      # @param precision [Fixnum] The precision of the percentage to return. *Ignored for list progress.*
      # @return [String] The formatted progress.
      def progress(current, total, type: :list, precision: 0)
        if type == :list
          compute_list_progress(current, total)
        else
          precision = [0, precision].max
          result = total == 0 ? 100 : (100 * (current.to_f / total))
          sprintf("%0.#{precision}f %%", result.round(precision)).rjust(5 + (precision > 0 ? precision + 1 : 0))
        end
      end

      # Writes a message prepending a green banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def begin(message, suffix: "\n", indented: true, wrap: false, plain: false, indented_banner: false, full_colored: false, print: true)
        banner = get_banner("*", "bright green", full_colored: full_colored)
        message = indent(message, indented_banner ? 0 : indented)
        write(banner + " " + message, suffix: suffix, indented: indented_banner ? indented : 0, wrap: wrap, plain: plain, print: print)
      end

      # Writes a message prepending a red banner and then quits the application.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param return_code [Fixnum] The code to return to the shell.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def fatal(message, suffix: "\n", indented: true, wrap: false, plain: false, indented_banner: false, full_colored: false, return_code: -1, print: true)
        error(message, suffix: suffix, indented: indented, wrap: wrap, plain: plain, indented_banner: indented_banner, full_colored: full_colored, print: print)
        Kernel.exit(return_code.to_integer(-1))
      end

      # Writes a message prepending a cyan banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      # @param banner [Array] An array with at last letter and style to use for the banner.
      #
      # @see #format
      def info(message, suffix: "\n", indented: true, wrap: false, plain: false, indented_banner: false, full_colored: false, print: true, banner: [])
        banner = banner.ensure_array(no_duplicates: true, compact: true, flatten: true)
        banner = ["I", "bright cyan"] if banner.blank?
        banner = get_banner(banner[0], banner[1], full_colored: full_colored)
        message = indent(message, indented_banner ? 0 : indented)
        write(banner + " " + message, suffix: suffix, indented: indented_banner ? indented : 0, wrap: wrap, plain: plain, print: print)
      end

      # Writes a message prepending a magenta banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def debug(message, suffix: "\n", indented: true, wrap: false, plain: false, indented_banner: false, full_colored: false, print: true)
        info(
          message,
          suffix: suffix,
          indented: indented,
          wrap: wrap,
          plain: plain,
          indented_banner: indented_banner,
          full_colored: full_colored,
          print: print,
          banner: ["D", "bright magenta"]
        )
      end

      # Writes a message prepending a yellow banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def warn(message, suffix: "\n", indented: true, wrap: false, plain: false, indented_banner: false, full_colored: false, print: true)
        info(
          message,
          suffix: suffix,
          indented: indented,
          wrap: wrap,
          plain: plain,
          indented_banner: indented_banner,
          full_colored: full_colored,
          print: print,
          banner: ["W", "bright yellow"]
        )
      end

      # Writes a message prepending a red banner.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param print [Boolean] If `false`, the result will be returned instead of be printed.
      #
      # @see #format
      def error(message, suffix: "\n", indented: true, wrap: false, plain: false, indented_banner: false, full_colored: false, print: true)
        info(
          message,
          suffix: suffix,
          indented: indented,
          wrap: wrap,
          plain: plain,
          indented_banner: indented_banner,
          full_colored: full_colored,
          print: print,
          banner: ["E", "bright red"]
        )
      end

      private

      # :nodoc:
      def compute_list_progress(current, total)
        @progress_list_widths ||= {}
        @progress_list_widths[total] ||= total.to_s.length
        sprintf("%0#{@progress_list_widths[total]}d/%d", current, total)
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
          `#{command}`
        end
      end

      # Reads a string from the console.
      #
      # @param prompt [String|Boolean] A prompt to show. If `true`, `Please insert a value:` will be used, if `nil` or `false` no prompt will be shown.
      # @param default_value [String] Default value if user simply pressed the enter key.
      # @param validator [Array|Regexp] An array of values or a Regexp to match the submitted value against.
      # @param echo [Boolean] If to show submitted text to the user. **Not supported and thus ignored on Rubinius.**
      def read(prompt: true, default_value: nil, validator: nil, echo: true)
        prompt = sanitize_prompt(prompt)
        validator = sanitize_validator(validator)

        begin
          catch(:reply) do
            loop do
              reply = validate_input_value(read_input_value(prompt, echo, default_value), validator)
              handle_reply(reply)
            end
          end
        rescue Interrupt
          default_value
        end
      end

      # Executes a block of code in a indentation region and then prints out and ending status message.
      #
      # @param message [String] The message to format.
      # @param suffix [Object] If not `nil` or `false`, a suffix to add to the message. `true` means to add `\n`.
      # @param indented [Object] If not `nil` or `false`, the width to use for indentation. `true` means to use the current indentation,
      #   a negative value of `-x` will indent of `x` absolute spaces.
      # @param wrap [Object] If not `nil` or `false`, the maximum length of a line for wrapped text. `true` means the current line width.
      # @param plain [Boolean] If ignore color markers into the message.
      # @param indented_banner [Boolean] If also the banner should be indented.
      # @param full_colored [Boolean] If the banner should be fully colored.
      # @param block_indentation [Fixnum] The new width for the indented region.
      # @param block_indentation_absolute [Boolean] If the new width should not be added to the current one but rather replace it.
      # @return [Symbol] The exit status for the block.
      def task(
        message = nil, suffix: "\n", indented: true, wrap: false, plain: false, indented_banner: false,
        full_colored: false, block_indentation: 2, block_indentation_absolute: false
      )
        status = nil

        if message.present?
          self.begin(message, suffix: suffix, indented: indented, wrap: wrap, plain: plain, indented_banner: indented_banner, full_colored: full_colored)
        end

        with_indentation(block_indentation, block_indentation_absolute) do
          rv = block_given? ? yield.ensure_array : [:ok] # Execute block
          exit_task(message, rv, plain) # Handle task exit
          status = rv[0] # Return value
        end

        status
      end

      private

      # :nodoc:
      def exit_task(message, rv, plain)
        if rv[0] == :fatal
          status(:fail, plain: plain)
          exit(rv.length > 1 ? rv[1].to_integer : -1)
        elsif message.present?
          status(rv[0], plain: plain)
        end
      end

      # :nodoc:
      def sanitize_prompt(prompt)
        return nil unless prompt.present?
        (prompt.is_a?(TrueClass) ? i18n.prompt : prompt).gsub(/:?\s*$/, "") + ": "
      end

      # :nodoc:
      def sanitize_validator(validator)
        if validator.present? && !validator.is_a?(::Regexp)
          validator.ensure_array(no_duplicates: true, compact: true, flatten: true, sanitizer: :ensure_string)
        else
          validator
        end
      end

      # :nodoc:
      def read_input_value(prompt, echo, default_value = nil)
        if prompt
          Kernel.print(format(prompt, suffix: false, indented: false))
          $stdout.flush
        end

        reply = (echo || !$stdin.respond_to?(:noecho) ? $stdin.gets : $stdin.noecho(&:gets)).ensure_string.chop
        reply.present? ? reply : default_value
      end

      # :nodoc:
      def validate_input_value(reply, validator)
        # Match against the validator
        if validator.present?
          if validator.is_a?(Array)
            reply = validate_array(reply, validator)
          elsif validator.is_a?(Regexp)
            reply = nil unless validator.match(reply)
          end
        end

        reply
      end

      # :nodoc:
      def validate_array(reply, validator)
        reply = nil if !validator.empty? && !validator.include?(reply)
        reply
      end

      # :nodoc:
      def handle_reply(reply)
        if reply
          throw(:reply, reply)
        else
          write(i18n.unknown_reply, false, false)
        end
      end
    end
  end

  # This is a text utility wrapper console I/O.
  #
  # @attribute indentation
  #   @return [Fixnum] Current indentation width.
  # @attribute indentation_string
  #   @return [String] The string used for indentation.
  # @attribute [r] i18n
  #   @return [I18n] A i18n helper.
  class Console
    attr_accessor :indentation, :indentation_string
    attr_reader :i18n

    include Bovem::ConsoleMethods::StyleHandling
    include Bovem::ConsoleMethods::Output
    include Bovem::ConsoleMethods::Logging
    include Bovem::ConsoleMethods::Interactions

    # Returns a unique instance for Console.
    #
    # @return [Console] A new instance.
    def self.instance
      @instance ||= Bovem::Console.new
    end

    # Initializes a new Console.
    def initialize
      @indentation = 0
      @indentation_string = " "
      @i18n = Bovem::I18n.new(root: "bovem.console", path: Bovem::Application::LOCALE_ROOT)
    end

    # Get the width of the terminal.
    #
    # @return [Fixnum] The current width of the terminal. If not possible to retrieve the width, it returns `80.
    def line_width
      require "io/console" unless defined?($stdin.winsize)
      $stdin.winsize[1]
    rescue
      80
    end
  end
end
