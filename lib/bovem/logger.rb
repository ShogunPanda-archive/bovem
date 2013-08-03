# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # A custom logger.
  #
  # @attribute [r] device
  #   @return [IO|String] The file or device to log messages to.
  class Logger < ::Logger
    attr_reader :device

    # Creates a new logger.
    #
    # @see http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html
    #
    # @param logdev [String|IO] The log device. This is a filename (String) or IO object (typically STDOUT, STDERR, or an open file).
    # @param shift_age [Fixnum]  Number of old log files to keep, or frequency of rotation (daily, weekly or monthly).
    # @param shift_size [Fixnum] Maximum logfile size (only applies when shift_age is a number).
    def initialize(logdev, shift_age = 0, shift_size = 1048576)
      @device = logdev
      super(logdev, shift_age, shift_size)
    end

    # Creates a new logger.
    #
    # @param file [String|IO] The log device. This is a filename (String) or IO object (typically STDOUT, STDERR, or an open file).
    # @param level [Fixnum] The minimum severity to log. See http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html for valid levels.
    # @param formatter [Proc] The formatter to use for logging.
    # @return [Logger] The new logger.
    def self.create(file = nil, level = Logger::INFO, formatter = nil)
      begin
        rv = new(get_real_file(file || default_file))
        rv.level = level.to_integer
        rv.formatter = formatter || default_formatter
        rv
      rescue
        raise Bovem::Errors::InvalidLogger
      end
    end

    # Translates a file to standard input or standard output in some special cases.
    #
    # @param file [String] The string to translate.
    # @return [String|IO] The translated file name.
    def self.get_real_file(file)
      case file
        when "STDOUT" then $stdout
        when "STDERR" then $stderr
        else file
      end
    end

    # The default file for logging.
    # @return [String|IO] The default file for logging.
    def self.default_file
      @default_file ||= $stdout
    end

    # The default formatter for logging.
    # @return [Proc] The default formatter for logging.
    def self.default_formatter
      @default_formatter ||= ::Proc.new {|severity, datetime, _, msg|
        color = case severity
          when "DEBUG" then :cyan
          when "INFO" then :green
          when "WARN" then :yellow
          when "ERROR" then :red
          when "FATAL" then :magenta
          else :white
        end

        header = Bovem::Console.replace_markers("{mark=bright-#{color}}[%s T+%0.5f] %s:{/mark}" %[datetime.strftime("%Y/%b/%d %H:%M:%S"), [datetime.to_f - start_time.to_f, 0].max, severity.rjust(5)])
        "%s %s\n" % [header, msg]
      }
    end

    # The log time of the first logger. This allows to show a `T+0.1234` information into the log.
    # @return [Time] The log time of the first logger.
    def self.start_time
      @start_time ||= ::Time.now
    end
  end
end