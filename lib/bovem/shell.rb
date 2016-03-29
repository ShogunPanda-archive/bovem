# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

module Bovem
  # Methods of the {Shell Shell} class.
  module ShellMethods
    # General methods.
    module General
      private

      # :nodoc:
      def handle_failure(e, access_error, not_found_error, general_error, entries, fatal, show_errors)
        error_type, final_entries = setup_error_handling(entries, fatal)

        case e.class.to_s
        when "Errno::EACCES" then @console.send(error_type, i18n.send(access_error, final_entries))
        when "Errno::ENOENT" then @console.send(error_type, i18n.send(not_found_error, final_entries))
        else show_general_failure(e, general_error, entries, fatal) if show_errors
        end
      end

      # :nodoc:
      def setup_error_handling(entries, fatal)
        [fatal ? :fatal : :error, entries.length == 1 ? entries[0] : entries]
      end

      # :nodoc:
      def show_general_failure(e, general_error, entries, fatal)
        @console.error(i18n.send(general_error))
        @console.with_indentation(11) do
          entries.each { |entry| @console.write(entry) }
        end

        @console.write(i18n.error(e.class.to_s, e), suffix: "\n", indented: 5)
        Kernel.exit(-1) if fatal
      end
    end

    # Methods to find or check entries.
    module Read
      # Tests a path against a list of test.
      #
      # Valid tests are every method available in http://www.ruby-doc.org/core-2.3.0/FileTest.html (plus `read`, `write`, `execute`, `exec`, `dir`).
      #   Trailing question mark can be omitted. Unrecognized tests will make the check fail.
      #
      # @param path [String] The path to test.
      # @param tests [Array] The list of tests to perform.
      def check(path, *tests)
        path = path.ensure_string

        tests.ensure_array(no_duplicates: true, compact: true, flatten: true).all? do |test|
          # Adjust test name
          test = test.ensure_string.strip

          test =
            case test
            when "read" then "readable"
            when "write" then "writable"
            when "execute", "exec" then "executable"
            when "dir" then "directory"
            else test
            end

          # Execute test
          test += "?" if test !~ /\?$/
          FileTest.respond_to?(test) ? FileTest.send(test, path) : nil
        end
      end

      # Find a list of files in directories matching given regexps or patterns.
      #
      # You can also pass a block to perform matching. The block will receive a single argument and the path will be considered if return value is not falsey.
      #
      # Inside the block, you can call `Find.prune` to stop searching in the current directory.
      #
      # @param directories [String] A list of directories where to search files.
      # @param patterns [Array] A list of regexps or patterns to match files. If empty, every file is returned. Ignored if a block is provided.
      # @param extension_only [Boolean] If to only search in extensions. Ignored if a block is provided.
      # @param case_sensitive [Boolean] If the search is case sensitive. Only meaningful for string patterns.
      # @param block [Proc] An optional block to perform matching instead of pattern matching.
      def find(directories, patterns: [], extension_only: false, case_sensitive: false, &block)
        rv = []

        directories = directories.ensure_array(no_duplicates: true, compact: true, flatten: true) { |d| File.expand_path(d.ensure_string) }
        patterns = normalize_patterns(patterns, extension_only, case_sensitive)

        directories.each do |directory|
          next unless check(directory, [:directory, :readable, :executable])
          Find.find(directory) do |entry|
            found = patterns.blank? ? true : match_pattern(entry, patterns, extension_only, &block)

            rv << entry if found
          end
        end

        rv
      end

      private

      # :nodoc:
      def normalize_patterns(patterns, by_extension, case_sensitive)
        # Adjust patterns
        patterns = patterns.ensure_array(no_duplicates: true, compact: true, flatten: true) do |p|
          p.is_a?(::Regexp) ? p : Regexp.new(Regexp.quote(p.ensure_string))
        end

        patterns = patterns.map { |p| /(#{p.source})$/ } if by_extension
        patterns = patterns.map { |p| /#{p.source}/i } unless case_sensitive
        patterns
      end

      # :nodoc:
      def match_pattern(entry, patterns, by_extension)
        catch(:found) do
          if block_given?
            throw(:found, true) if yield(entry)
          else
            patterns.each do |pattern|
              throw(:found, true) if pattern.match(entry) && (!by_extension || !File.directory?(entry))
            end
          end

          false
        end
      end
    end

    # Methods to copy or move entries.
    module Write
      # Copies a set of files or directory to another location.
      #
      # @param src [String|Array] The entries to copy. If is an Array, `dst` is assumed to be a directory.
      # @param dst [String] The destination. **Any existing entries will be overwritten.** Any required directory will be created.
      # @param run [Boolean] If `false`, it will just print a list of message that would be copied or moved.
      # @param show_errors [Boolean] If show errors.
      # @param fatal_errors [Boolean] If quit in case of fatal errors.
      # @return [Boolean] `true` if operation succeeded, `false` otherwise.
      def copy(src, dst, run: true, show_errors: false, fatal_errors: true)
        copy_or_move(src, dst, operation: :copy, run: run, show_errors: show_errors, fatal_errors: fatal_errors)
      end

      # Moves a set of files or directory to another location.
      #
      # @param src [String|Array] The entries to move. If is an Array, `dst` is assumed to be a directory.
      # @param dst [String] The destination. **Any existing entries will be overwritten.** Any required directory will be created.
      # @param run [Boolean] If `false`, it will just print a list of message that would be deleted.
      # @param show_errors [Boolean] If show errors.
      # @param fatal_errors [Boolean] If quit in case of fatal errors.
      # @return [Boolean] `true` if operation succeeded, `false` otherwise.
      def move(src, dst, run: true, show_errors: false, fatal_errors: true)
        copy_or_move(src, dst, operation: :move, run: run, show_errors: show_errors, fatal_errors: fatal_errors)
      end

      private

      # :nodoc:
      def copy_or_move(src, dst, operation, run = true, show_errors = true, fatal = true)
        rv = true
        operation, operation_s, single, src, dst = sanitize_copy_or_move(operation, src, dst)

        if !run
          dry_run_copy_or_move(single, operation_s, src, dst)
        else
          rv = catch(:rv) do
            dst_dir = prepare_destination(single, src, dst, operation_s, show_errors, fatal)
            check_sources(src, operation_s, fatal)
            execute_copy_or_move(src, dst, dst_dir, single, operation, operation_s, show_errors, fatal)
            true
          end
        end

        rv
      end

      # :nodoc:
      def sanitize_copy_or_move(operation, src, dst)
        operation = :copy if operation != :move
        single = !src.is_a?(Array)
        src = single ? File.expand_path(src) : src.map { |s| File.expand_path(s) }

        [operation, i18n.send(operation), single, src, File.expand_path(dst.ensure_string)]
      end

      # :nodoc:
      def dry_run_copy_or_move(single, operation, src, dst)
        if single
          dry_run_copy_or_move_single(src, dst, operation)
        else
          dry_run_copy_or_move_multi(src, dst, operation)
        end
      end

      # :nodoc:
      def dry_run_copy_or_move_single(src, dst, operation)
        @console.warn(i18n.copy_move_single_dry(operation))
        @console.write(i18n.copy_move_from(File.expand_path(src.ensure_string)), suffix: "\n", indented: 11)
        @console.write(i18n.copy_move_to(dst), suffix: "\n", indented: 11)
      end

      # :nodoc:
      def dry_run_copy_or_move_multi(src, dst, operation)
        @console.warn(i18n.copy_move_multi_dry(operation))
        @console.with_indentation(11) do
          src.each do |s|
            @console.write(s)
          end
        end
        @console.write(i18n.copy_move_to_multi(dst), suffix: "\n", indented: 5)
      end

      # :nodoc:
      def prepare_destination(single, src, dst, operation, show_errors, fatal)
        dst_dir = single ? File.dirname(dst) : dst
        has_dir = check(dst_dir, :dir)

        # Create directory
        has_dir = create_directories(dst_dir, mode: 0755, show_errors: show_errors, fatal_errors: fatal) unless has_dir
        throw(:rv, false) unless has_dir

        # Check if the destination directory is a file in single mode
        if single && check(dst, :dir)
          @console.send(fatal ? :fatal : :error, i18n.copy_move_single_to_directory(operation, src, dst))
          throw(:rv, false)
        end

        dst_dir
      end

      # :nodoc:
      def check_sources(src, operation, fatal)
        # Check that every file is existing
        src.ensure_array.each do |s|
          unless check(s, :exists)
            @console.send(fatal ? :fatal : :error, i18n.copy_move_src_not_found(operation, s))
            throw(:rv, false)
          end
        end
      end

      # :nodoc:
      def execute_copy_or_move(src, dst, dst_dir, single, operation, operation_s, show_errors, fatal)
        FileUtils.send(operation == :move ? :mv : :cp_r, src, dst, {noop: false, verbose: false})
      rescue Errno::EACCES
        handle_copy_or_move_access_error(src, dst, dst_dir, single, operation_s, show_errors, fatal)
      rescue => e
        handle_copy_or_move_general_erorr(src, dst, dst_dir, single, e, operation_s, show_errors, fatal)
      end

      # :nodoc:
      def handle_copy_or_move_general_erorr(src, dst, dst_dir, single, e, operation_s, show_errors, fatal)
        single_msg = i18n.copy_move_error_single(operation_s, src, dst_dir, e.class.to_s, e)
        multi_msg = i18n.copy_move_error_multi(operation_s, dst)
        handle_copy_or_move_failure(single, src, show_errors, fatal, single_msg, multi_msg, i18n.error(e.class.to_s, e))
      end

      # :nodoc:
      def handle_copy_or_move_access_error(src, dst, dst_dir, single, operation_s, show_errors, fatal)
        single_msg = i18n.copy_move_dst_not_writable_single(operation_s, src, dst_dir)
        multi_msg = i18n.copy_move_dst_not_writable_multi(operation_s, dst)
        handle_copy_or_move_failure(single, src, show_errors, fatal, single_msg, multi_msg, nil)
      end

      # :nodoc:
      def handle_copy_or_move_failure(single, src, show_errors, fatal, single_msg, multi_msg, error)
        if fatal || show_errors
          if single
            @console.send(fatal ? :fatal : :error, single_msg, suffix: "\n", indented: 5)
          else
            show_copy_move_failed_files(src, error, multi_msg)
            Kernel.exit(-1) if fatal
          end
        end

        throw(:rv, false)
      end

      # :nodoc:
      def show_copy_move_failed_files(src, error, multi_msg)
        @console.error(multi_msg)
        @console.with_indentation(11) do
          src.each do |s|
            @console.write(s)
          end
        end
        @console.write(error, suffix: "\n", indented: 5) if error
      end
    end

    # Methods to run commands or delete entries.
    module Execute
      # Runs a command into the shell.
      #
      # @param command [String] The string to run.
      # @param message [String] A message to show before running.
      # @param run [Boolean] If `false`, it will just print a message with the full command that will be run.
      # @param show_exit [Boolean] If show the exit status.
      # @param show_output [Boolean] If show command output.
      # @param show_command [Boolean] If show the command that will be run.
      # @param fatal_errors [Boolean] If quit in case of fatal errors.
      # @return [Hash] An hash with `status` and `output` keys.
      def run(command, message = nil, run: true, show_exit: true, show_output: false, show_command: false, fatal_errors: true)
        rv = {status: 0, output: ""}
        command = command.ensure_string

        # Show the command
        @console.begin(message) if message.present?

        if !run # Print a message
          show_dry_run(command, show_exit)
        else # Run
          rv = execute_command(command, show_command, show_output)
        end

        # Return
        handle_command_exit(rv, show_exit, fatal_errors)
        rv
      end

      # Deletes a list of files.
      #
      # @param files [Array] The list of files to remove
      # @param run [Boolean] If `false`, it will just print a list of message that would be deleted.
      # @param show_errors [Boolean] If show errors.
      # @param fatal_errors [Boolean] If quit in case of fatal errors.
      # @return [Boolean] `true` if operation succeeded, `false` otherwise.
      def delete(*files, run: true, show_errors: false, fatal_errors: true)
        rv = true
        files = files.ensure_array(no_duplicates: true, compact: true, flatten: true) { |f| File.expand_path(f.ensure_string) }

        if !run
          show_dry_delete(files)
        else
          rv = perform_delete(files, show_errors, fatal_errors)
        end

        rv
      end

      private

      # :nodoc:
      def execute_command(command, show_command, show_output)
        output = ""

        @console.info(i18n.run(command)) if show_command
        status = ::Open4.popen4(command + " 2>&1") do |_, _, stdout, _|
          stdout.each_line do |line|
            output << line
            Kernel.print line if show_output
          end
        end

        {status: status.exitstatus, output: output}
      end

      # :nodoc:
      def handle_command_exit(rv, show_exit, fatal_errors)
        @console.status(rv[:status] == 0 ? :ok : :fail) if show_exit
        exit(rv[:status]) if fatal_errors && rv[:status] != 0
      end

      # :nodoc:
      def show_dry_run(command, show_exit)
        @console.warn(i18n.run_dry(command))
        @console.status(:ok) if show_exit
      end

      # :nodoc:
      def perform_delete(files, show_errors, fatal)
        catch(:rv) do
          begin
            FileUtils.rm_r(files, {noop: false, verbose: false, secure: true})
            throw(:rv, true)
          rescue => e
            handle_failure(e, :remove_unwritable, :remove_not_found, :remove_error, files, fatal, show_errors)
          end

          false
        end
      end

      # :nodoc:
      def show_dry_delete(files)
        @console.warn(i18n.remove_dry)
        @console.with_indentation(11) do
          files.each do |file|
            @console.write(file)
          end
        end
      end
    end

    # Methods to interact with directories.
    module Directories
      # Executes a block of code in another directory.
      #
      # @param directory [String] The new working directory.
      # @param restore [Boolean] If to restore the original working directory.
      # @param show_messages [Boolean] Show informative messages about working directory changes.
      # @return [Boolean] `true` if the directory was valid and the code executed, `false` otherwise.
      def within_directory(directory, restore: true, show_messages: false)
        directory = File.expand_path(directory.ensure_string)
        original = Dir.pwd

        rv = enter_directory(directory, show_messages, i18n.move_in(directory))
        yield if rv && block_given?
        rv = enter_directory(original, show_messages, i18n.move_out(directory)) if rv && restore

        rv
      end

      # Creates a list of directories, included missing parent directories.
      #
      # @param directories [Array] The list of directories to create.
      # @param mode [Fixnum] Initial permissions for the new directories.
      # @param run [Boolean] If `false`, it will just print a list of directories that would be created.
      # @param show_errors [Boolean] If show errors.
      # @param fatal_errors [Boolean] If quit in case of fatal errors.
      # @return [Boolean] `true` if operation succeeded, `false` otherwise.
      def create_directories(*directories, mode: 0755, run: true, show_errors: false, fatal_errors: true)
        rv = true

        # Adjust directory
        directories = directories.ensure_array(no_duplicates: true, compact: true, flatten: true) { |d| File.expand_path(d.ensure_string) }

        if !run # Just print
          dry_run_directory_creation(directories)
        else
          directories.each do |directory|
            rv &&= try_create_directory(directory, mode, fatal_errors, directories, show_errors)
            break unless rv
          end
        end

        rv
      end

      private

      # :nodoc:
      def enter_directory(directory, show_message, message)
        raise ArgumentError unless check(directory, :directory, :executable)
        @console.info(message) if show_message
        Dir.chdir(directory)
        true
      rescue
        false
      end

      # :nodoc:
      def dry_run_directory_creation(directories)
        @console.warn(i18n.mkdir_dry)
        @console.with_indentation(11) do
          directories.each do |directory|
            @console.write(directory)
          end
        end
      end

      # :nodoc:
      def try_create_directory(directory, mode, fatal, directories, show_errors)
        rv = false

        # Perform tests
        if check(directory, :directory)
          @console.send(fatal ? :fatal : :error, i18n.mkdir_existing(directory))
        elsif check(directory, :exist)
          @console.send(fatal ? :fatal : :error, i18n.mkdir_file(directory))
        else
          rv = create_directory(directory, mode, fatal, directories, show_errors)
        end

        rv
      end

      # :nodoc:
      def create_directory(directory, mode, fatal, directories, show_errors)
        rv = false

        begin # Create directory
          FileUtils.mkdir_p(directory, {mode: mode, noop: false, verbose: false})
          rv = true
        rescue => e
          handle_failure(e, :mkdir_denied, nil, :mkdir_error, directories, fatal, show_errors)
        end

        rv
      end
    end
  end

  # A utility class for most common shell operation.
  #
  # @attribute console
  #   @return [Console] A console instance.
  # @attribute [r] i18n
  #   @return [I18n] A i18n helper.
  class Shell
    include Bovem::ShellMethods::General
    include Bovem::ShellMethods::Read
    include Bovem::ShellMethods::Write
    include Bovem::ShellMethods::Execute
    include Bovem::ShellMethods::Directories

    attr_accessor :console
    attr_reader :i18n

    # Returns a unique instance for Shell.
    #
    # @return [Shell] A new instance.
    def self.instance
      @instance ||= Bovem::Shell.new
    end

    # Initializes a new Shell.
    def initialize
      @console = Bovem::Console.instance
      @i18n = Bovem::I18n.new(root: "bovem.shell", path: ::File.absolute_path(::Pathname.new(::File.dirname(__FILE__)).to_s + "/../../locales/"))
    end
  end
end
