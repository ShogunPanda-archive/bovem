# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # A utility class for most common shell operation.
  #
  # @attr [Console] console # A console instance.
  class Shell
    include Lazier::I18n

    attr_accessor :console

    # Returns a unique instance for Shell.
    #
    # @return [Shell] A new instance.
    def self.instance
      @instance ||= ::Bovem::Shell.new
    end

    # Initializes a new Shell.
    def initialize
      @console = ::Bovem::Console.instance
      self.i18n_setup(:bovem, ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"))
    end

    # Runs a command into the shell.
    #
    # @param command [String] The string to run.
    # @param message [String] A message to show before running.
    # @param run [Boolean] If `false`, it will just print a message with the full command that will be run.
    # @param show_exit [Boolean] If show the exit status.
    # @param show_output [Boolean] If show command output.
    # @param show_command [Boolean] If show the command that will be run.
    # @param fatal [Boolean] If quit in case of fatal errors.
    # @return [Hash] An hash with `status` and `output` keys.
    def run(command, message = nil, run = true, show_exit = true, show_output = false, show_command = false, fatal = true)
      rv = {status: 0, output: ""}
      command = command.ensure_string

      # Show the command
      self.console.begin(message) if message.present?


      if !run then # Print a message
        self.console.warn(self.i18n.shell.run_dry(command))
        self.console.status(:ok) if show_exit
      else # Run
        output = ""

        self.console.info(self.i18n.shell.run(command)) if show_command
        rv[:status] = ::Open4::popen4(command + " 2>&1") { |pid, stdin, stdout, stderr|
          stdout.each_line do |line|
            output << line
            Kernel.print line if show_output
          end
        }.exitstatus

        rv[:output] = output
      end

      # Return
      self.console.status(rv[:status] == 0 ? :ok : :fail) if show_exit
      exit(rv[:status]) if fatal && rv[:status] != 0
      rv
    end

    # Tests a path against a list of test.
    #
    # Valid tests are every method available in http://www.ruby-doc.org/core-1.9.3/FileTest.html (plus `read`, `write`, `execute`, `exec`, `dir`). Trailing question mark can be omitted.
    #
    #
    # @param path [String] The path to test.
    # @param tests [Array] The list of tests to perform.
    def check(path, tests)
      path = path.ensure_string

      tests.ensure_array.all? {|test|
        # Adjust test name
        test = test.ensure_string.strip

        test = case test
          when "read" then "readable"
          when "write" then "writable"
          when "execute", "exec" then "executable"
          when "dir" then "directory"
          else test
        end

        # Execute test
        test += "?" if test !~ /\?$/
        FileTest.respond_to?(test) ? FileTest.send(test, path) : nil
      }
    end

    # Deletes a list of files.
    #
    # @param files [Array] The list of files to remove
    # @param run [Boolean] If `false`, it will just print a list of message that would be deleted.
    # @param show_errors [Boolean] If show errors.
    # @param fatal [Boolean] If quit in case of fatal errors.
    # @return [Boolean] `true` if operation succeeded, `false` otherwise.
    def delete(files, run = true, show_errors = false, fatal = true)
      rv = true
      files = files.ensure_array.compact.collect {|f| File.expand_path(f.ensure_string) }

      if !run then
        self.console.warn(self.i18n.shell.remove_dry)
        self.console.with_indentation(11) do
          files.each do |file| self.console.write(file) end
        end
      else
        rv = catch(:rv) do
          begin
            FileUtils.rm_r(files, {noop: false, verbose: false, secure: true})
            throw(:rv, true)
          rescue Errno::EACCES => e
            self.console.send(fatal ? :fatal : :error, self.i18n.shell.remove_unwritable(e.message.gsub(/.+ - (.+)/, "\\1")))
          rescue Errno::ENOENT => e
            self.console.send(fatal ? :fatal : :error, self.i18n.shell.remove_not_found(e.message.gsub(/.+ - (.+)/, "\\1")))
          rescue Exception => e
            if show_errors then
              self.console.error(self.i18n.shell.remove_error)
              self.console.with_indentation(11) do
                files.each do |file| self.console.write(file) end
              end
              self.console.write(self.i18n.shell.error(e.class.to_s, e), "\n", 5)
              Kernel.exit(-1) if fatal
            end
          end

          false
        end
      end

      rv
    end

    # Copies or moves a set of files or directory to another location.
    #
    # @param src [String|Array] The entries to copy or move. If is an Array, `dst` is assumed to be a directory.
    # @param dst [String] The destination. **Any existing entries will be overwritten.** Any required directory will be created.
    # @param operation [Symbol] The operation to perform. Valid values are `:copy` or `:move`.
    # @param run [Boolean] If `false`, it will just print a list of message that would be copied or moved.
    # @param show_errors [Boolean] If show errors.
    # @param fatal [Boolean] If quit in case of fatal errors.
    # @return [Boolean] `true` if operation succeeded, `false` otherwise.
    def copy_or_move(src, dst, operation, run = true, show_errors = false, fatal = true)
      rv = true
      operation = :copy if operation != :move
      operation_s = self.i18n.shell.send(operation)
      single = !src.is_a?(Array)

      if single then
        src = File.expand_path(src)
      else
        src = src.collect {|s| File.expand_path(s) }
      end

      dst = File.expand_path(dst.ensure_string)

      if !run then
        if single then
          self.console.warn(self.i18n.shell.copy_move_single_dry(operation_s))
          self.console.write(self.i18n.shell.copy_move_from(File.expand_path(src.ensure_string)), "\n", 11)
          self.console.write(self.i18n.shell.copy_move_to(dst), "\n", 11)
        else
          self.console.warn(self.i18n.shell.copy_move_multi_dry(operation_s))
          self.console.with_indentation(11) do
            src.each do |s| self.console.write(s) end
          end
          self.console.write(self.i18n.shell.copy_move_to_multi(dst), "\n", 5)
        end
      else
        rv = catch(:rv) do
          dst_dir = single ? File.dirname(dst) : dst
          has_dir = self.check(dst_dir, :dir)

          # Create directory
          has_dir = self.create_directories(dst_dir, 0755, true, show_errors, fatal) if !has_dir
          throw(:rv, false) if !has_dir

          if single && self.check(dst, :dir) then
            @console.send(fatal ? :fatal : :error, self.i18n.shell.copy_move_single_to_directory(operation_s, src, dst))
            throw(:rv, false)
          end

          # Check that every file is existing
          src.ensure_array.each do |s|
            if !self.check(s, :exists) then
              @console.send(fatal ? :fatal : :error, self.i18n.shell.copy_move_src_not_found(operation_s, s))
              throw(:rv, false)
            end
          end

          # Do operation
          begin
            FileUtils.send(operation == :move ? :mv : :cp_r, src, dst, {noop: false, verbose: false})
          rescue Errno::EACCES => e
            if single then
              @console.send(fatal ? :fatal : :error, self.i18n.shell.copy_move_dst_not_writable_single(operation_s, src, dst_dir))
            else
              self.console.error(self.i18n.shell.copy_move_dst_not_writable_single(operation_s, dst))
              self.console.with_indentation(11) do
                src.each do |s| self.console.write(s) end
              end
              Kernel.exit(-1) if fatal
            end

            throw(:rv, false)
          rescue Exception => e
            if single then
              @console.send(fatal ? :fatal : :error, self.i18n.shell.copy_move_error_single(operation_s, src, dst_dir, e.class.to_s, e), "\n", 5)
            else
              self.console.error(self.i18n.shell.copy_move_error_multi(operation_s, dst))
              self.console.with_indentation(11) do
                src.each do |s| self.console.write(s) end
              end
              self.console.write(self.i18n.shell.error(e.class.to_s, e), "\n", 5)
              Kernel.exit(-1) if fatal
            end

            throw(:rv, false)
          end

          true
        end
      end

      rv
    end

    # Copies a set of files or directory to another location.
    #
    # @param src [String|Array] The entries to copy. If is an Array, `dst` is assumed to be a directory.
    # @param dst [String] The destination. **Any existing entries will be overwritten.** Any required directory will be created.
    # @param run [Boolean] If `false`, it will just print a list of message that would be copied or moved.
    # @param show_errors [Boolean] If show errors.
    # @param fatal [Boolean] If quit in case of fatal errors.
    # @return [Boolean] `true` if operation succeeded, `false` otherwise.
    def copy(src, dst, run = true, show_errors = false, fatal = true)
      self.copy_or_move(src, dst, :copy, run, show_errors, fatal)
    end

    # Moves a set of files or directory to another location.
    #
    # @param src [String|Array] The entries to move. If is an Array, `dst` is assumed to be a directory.
    # @param dst [String] The destination. **Any existing entries will be overwritten.** Any required directory will be created.
    # @param run [Boolean] If `false`, it will just print a list of message that would be deleted.
    # @param show_errors [Boolean] If show errors.
    # @param fatal [Boolean] If quit in case of fatal errors.
    # @return [Boolean] `true` if operation succeeded, `false` otherwise.
    def move(src, dst, run = true, show_errors = false, fatal = true)
      self.copy_or_move(src, dst, :move, run, show_errors, fatal)
    end

    # Executes a block of code in another directory.
    #
    # @param directory [String] The new working directory.
    # @param restore [Boolean] If to restore the original working directory.
    # @param show_messages [Boolean] Show informative messages about working directory changes.
    # @return [Boolean] `true` if the directory was valid and the code executed, `false` otherwise.
    def within_directory(directory, restore = true, show_messages = false)
      rv = false
      original = Dir.pwd
      directory = File.expand_path(directory.ensure_string)

      if self.check(directory, [:directory, :executable]) then
        begin
          self.console.info(self.i18n.shell.move_in(directory)) if show_messages
          Dir.chdir(directory)
          rv = true
        rescue Exception => e
        end
      end

      yield if rv && block_given?

      if rv && original then
        begin
          self.console.info(self.i18n.shell.move_out(original)) if show_messages
          Dir.chdir(original) if restore
        rescue Exception => e
          rv = false
        end
      end

      rv
    end

    # Creates a list of directories, included missing parent directories.
    #
    # @param directories [Array] The list of directories to create.
    # @param mode [Fixnum] Initial permissions for the new directories.
    # @param run [Boolean] If `false`, it will just print a list of directories that would be created.
    # @param show_errors [Boolean] If show errors.
    # @param fatal [Boolean] If quit in case of fatal errors.
    # @return [Boolean] `true` if operation succeeded, `false` otherwise.
    def create_directories(directories, mode = 0755, run = true, show_errors = false, fatal = true)
      rv = true

      # Adjust directory
      directories = directories.ensure_array.compact {|d| File.expand_path(d.ensure_string) }

      if !run then # Just print
        self.console.warn(self.i18n.shell.mkdir_dry)
        self.console.with_indentation(11) do
          directories.each do |directory| self.console.write(directory) end
        end
      else
        directories.each do |directory|
          rv = catch(:rv) do
            # Perform tests
            if self.check(directory, :directory) then
              self.console.send(fatal ? :fatal : :error, self.i18n.shell.mkdir_existing(directory))
            elsif self.check(directory, :exist) then
              self.console.send(fatal ? :fatal : :error, self.i18n.shell.mkdir_file(directory))
            else
              begin # Create directory
                FileUtils.mkdir_p(directory, {mode: mode, noop: false, verbose: false})
                throw(:rv, true)
              rescue Errno::EACCES => e
                self.console.send(fatal ? :fatal : :error, self.i18n.shell.mkdir_denied(e.message.gsub(/.+ - (.+)/, "\\1")))
              rescue Exception => e
                if show_errors then
                  self.console.error(self.i18n.shell.mkdir_error)
                  self.console.with_indentation(11) do
                    directories.each do |directory| self.console.write(directory) end
                  end
                  self.console.write(self.i18n.shell.error(e.class.to_s, e), "\n", 5)
                  Kernel.exit(-1) if fatal
                end
              end
            end

            false
          end

          break if !rv
        end
      end

      rv
    end

    # Find a list of files in directories matching given regexps or patterns.
    #
    # You can also pass a block to perform matching. The block will receive a single argument and the path will be considered matched if the blocks not evaluates to `nil` or `false`.
    #
    # Inside the block, you can call `Find.prune` to stop searching in the current directory.
    #
    # @param directories [String] A list of directories where to search files.
    # @param patterns [Array] A list of regexps or patterns to match files. If empty, every file is returned. Ignored if a block is provided.
    # @param by_extension [Boolean] If to only search in extensions. Ignored if a block is provided.
    # @param case_sensitive [Boolean] If the search is case sensitive. Only meaningful for string patterns.
    def find(directories, patterns = [], by_extension = false, case_sensitive = false)
      rv = []

      # Adjust directory
      directories = directories.ensure_array.compact {|d| File.expand_path(d.ensure_string) }

      # Adjust patterns
      patterns = patterns.ensure_array.compact.collect {|p| p.is_a?(::Regexp) ? p : Regexp.new(Regexp.quote(p.ensure_string)) }
      patterns = patterns.collect {|p| /(#{p.source})$/ } if by_extension
      patterns = patterns.collect {|p| /#{p.source}/i } if !case_sensitive

      directories.each do |directory|
        if self.check(directory, [:directory, :readable, :executable]) then
          Find.find(directory) do |entry|
            found = patterns.blank? ? true : catch(:found) do
              if block_given? then
                throw(:found, true) if yield(entry)
              else
                patterns.each do |pattern|
                  throw(:found, true) if pattern.match(entry) && (!by_extension || !File.directory?(entry))
                end
              end

              false
            end

            rv << entry if found
          end
        end
      end

      rv
    end
  end
end