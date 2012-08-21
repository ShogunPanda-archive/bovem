# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Bovem::Shell do
  let(:shell) { ::Bovem::Shell.new }
  let(:temp_file_1) { "/tmp/bovem-test-1-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:temp_file_2) { "/tmp/bovem-test-2-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:temp_file_3) { "/tmp/bovem-test-3-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:temp_dir_1) { "/tmp/bovem-test-dir-1-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:temp_dir_2) { "/tmp/bovem-test-dir-2-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }

  before(:each) do
    Kernel.stub(:puts).and_return(nil)
  end

  describe ".instance" do
    it "should always return the same instance" do
      instance = ::Bovem::Shell.instance
      expect(::Bovem::Shell.instance).to be(instance)
    end
  end

  describe "#initialize" do
    it "should correctly set defaults" do
      expect(shell.console).to eq(::Bovem::Console.instance)
    end
  end

  describe "#run" do
    it "should show a message" do
      shell.console.should_receive("begin").with("MESSAGE")
      shell.run("echo OK", "MESSAGE", true, false)
      shell.console.should_not_receive("begin").with("MESSAGE")
      shell.run("echo OK", nil, true, false)
    end

    it "should print the command line" do
      shell.console.should_receive("info").with("Running command: {mark=bright}\"echo OK\"{/mark}...")
      shell.run("echo OK", nil, true, false, false, true)
    end

    it "should only print the command if requested to" do
      shell.console.should_receive("warn").with("Will run command: {mark=bright}\"echo OK\"{/mark}...")
      ::Open4.should_not_receive("open4")
      shell.run("echo OK", nil, false, false)
    end

    it "should only execute a command" do
      shell.console.should_not_receive("warn").with("Will run command: {mark=bright}\"echo OK\"{/mark}...")
      ::Open4.should_receive("open4").and_return(::OpenStruct.new(:exitstatus => 0))
      shell.run("echo OK", nil, true, false)
    end

    it "should show a exit message" do
      shell.console.should_receive(:status).with(:ok)
      shell.run("echo OK", nil, true, true)
      shell.console.should_receive(:status).with(:fail)
      shell.run("echo1 OK", nil, true, true, false, false, false)
    end

    it "should print output" do
      Kernel.should_receive("print").with("OK\n")
      shell.run("echo OK", nil, true, false, true)
    end

    it "should raise a exception for failures" do
      expect { shell.run("echo1 OK", nil, true, false, false, false, false) }.to_not raise_error(SystemExit)
      expect { shell.run("echo1 OK", nil, true, false, false) }.to raise_error(SystemExit)
    end
  end

  describe "#check" do
    it "executes all tests" do
      expect(shell.check("/", [:read, :dir])).to be_true
      expect(shell.check("/dev/null", :write)).to be_true
      expect(shell.check("/bin/sh", [:execute, :exec])).to be_true
      expect(shell.check("/", [:read, :directory])).to be_true
      expect(shell.check("/", [:writable?, :directory?])).to be_false
    end

    it "returns false when some tests are invalid" do
      expect(shell.check("/", [:read, :none])).to be_false
    end
  end

  describe "#delete" do
    it "should delete files" do
      File.unlink(temp_file_1) if File.exists?(temp_file_1)
      File.open(temp_file_1, "w") {|f| f.write("OK") }

      expect(File.exists?(temp_file_1)).to be_true
      expect(shell.delete(temp_file_1, true, false)).to be_true
      expect(File.exists?(temp_file_1)).to be_false
      File.unlink(temp_file_1) if File.exists?(temp_file_1)
    end

    it "should only print the list of files" do
      shell.console.should_receive(:warn).with("Will remove file(s):")
      FileUtils.should_not_receive(:rm_r)
      expect(shell.delete(temp_file_1, false)).to be_true
    end

    it "should complain about non existing files" do
      shell.console.should_receive(:error).with("Cannot remove following non existent file: {mark=bright}#{temp_file_1}{/mark}")
      expect(shell.delete(temp_file_1, true, true, false)).to be_false
    end

    it "should complain about non writeable files" do
      shell.console.should_receive(:error).with("Cannot remove following non writable file: {mark=bright}/dev/null{/mark}")
      expect(shell.delete("/dev/null", true, true, false)).to be_false
    end

    it "should complain about other exceptions" do
      FileUtils.stub(:rm_r).and_raise(ArgumentError.new("ERROR"))
      shell.console.should_receive(:error).with("Cannot remove following file(s):")
      shell.console.should_receive(:write).at_least(2)
      expect(shell.delete("/dev/null", true, true, false)).to be_false
    end

    describe "should exit when requested to" do
      it "by calling :fatal" do
        shell.console.should_receive(:fatal).with("Cannot remove following non writable file: {mark=bright}/dev/null{/mark}")
        expect(shell.delete("/dev/null")).to be_false
      end

      it "by calling Kernel#exit" do
        FileUtils.stub(:rm_r).and_raise(ArgumentError.new("ERROR"))
        Kernel.should_receive(:exit).with(-1)
        expect(shell.delete("/dev/null", true, true)).to be_false
      end
    end
  end

  describe "#copy_or_move" do
    before(:each) do
      FileUtils.rm_r(temp_file_1) if File.exists?(temp_file_1)
      FileUtils.rm_r(temp_file_2) if File.exists?(temp_file_2)
      FileUtils.rm_r(temp_file_3) if File.exists?(temp_file_3)
      FileUtils.rm_r(temp_dir_1) if File.exists?(temp_dir_1)
      FileUtils.rm_r(temp_dir_2) if File.exists?(temp_dir_2)
    end

    after(:each) do
      FileUtils.rm_r(temp_file_1) if File.exists?(temp_file_1)
      FileUtils.rm_r(temp_file_2) if File.exists?(temp_file_2)
      FileUtils.rm_r(temp_file_3) if File.exists?(temp_file_3)
      FileUtils.rm_r(temp_dir_1) if File.exists?(temp_dir_1)
      FileUtils.rm_r(temp_dir_2) if File.exists?(temp_dir_2)
    end

    it "should copy a file" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :copy)).to eq(true)
      expect(File.exists?(temp_file_1)).to be_true
      expect(File.exists?(temp_file_2)).to be_true
    end

    it "should move a file" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :move, true)).to eq(true)
      expect(File.exists?(temp_file_1)).to be_false
      expect(File.exists?(temp_file_2)).to be_true
    end

    it "should copy multiple entries" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      File.open(temp_file_2, "w") {|f| f.write("OK") }
      shell.create_directories(temp_dir_1)
      File.open(temp_dir_1 + "/temp", "w") {|f| f.write("OK") }

      expect(shell.copy_or_move([temp_file_1, temp_file_2, temp_dir_1], temp_dir_2, :copy)).to be_true
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_file_1))).to be_true
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_file_2))).to be_true
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_dir_1))).to be_true
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_dir_1) + "/temp")).to be_true
    end

    it "should move multiple entries" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      File.open(temp_file_2, "w") {|f| f.write("OK") }
      shell.create_directories(temp_dir_1)
      File.open(temp_dir_1 + "/temp", "w") {|f| f.write("OK") }

      expect(shell.copy_or_move([temp_file_1, temp_file_2, temp_dir_1], temp_dir_2, :move, true)).to be_true
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_file_1))).to be_true
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_file_2))).to be_true
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_dir_1))).to be_true
      expect(File.exists?(temp_dir_2 + "/" + File.basename(temp_dir_1) + "/temp")).to be_true
      expect(File.exists?(temp_file_1)).to be_false
      expect(File.exists?(temp_file_2)).to be_false
      expect(File.exists?(temp_dir_1)).to be_false
      expect(File.exists?(temp_dir_1 + "/temp")).to be_false
    end

    it "should complain about non existing source" do
      shell.console.should_receive(:error).with("Cannot copy non existent file {mark=bright}#{temp_file_1}{/mark}.")
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :copy, true, false, false)).to be_false

      shell.console.should_receive(:error).with("Cannot move non existent file {mark=bright}#{temp_file_1}{/mark}.")
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :move, true, false, false)).to be_false
    end

    it "should not copy a file to a path which is currently a directory" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }
      shell.create_directories(temp_file_2)

      shell.console.should_receive(:error).with("Cannot copy file {mark=bright}#{temp_file_1}{/mark} to {mark=bright}#{temp_file_2}{/mark} because it is currently a directory.")
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :copy, true, false, false)).to be_false

      shell.console.should_receive(:error).with("Cannot move file {mark=bright}#{temp_file_1}{/mark} to {mark=bright}#{temp_file_2}{/mark} because it is currently a directory.")
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :move, true, false, false)).to be_false
    end

    it "should create the parent directory if needed" do
      expect(shell.check(temp_dir_1, :dir)).to be_false

      shell.should_receive(:create_directories).exactly(2)
      expect(shell.copy_or_move(temp_file_1, temp_dir_1 + "/test-1", :copy)).to be_false
      expect(shell.copy_or_move(temp_file_1, temp_dir_1 + "/test-1", :move)).to be_false
    end

    it "should only print the list of files" do
      FileUtils.should_not_receive(:cp_r)
      FileUtils.should_not_receive(:move)

      shell.console.should_receive(:warn).with("Will copy a file:")
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :copy, false)).to be_true
      shell.console.should_receive(:warn).with("Will copy following entries:")
      expect(shell.copy_or_move([temp_file_1, temp_file_2], temp_dir_1, :copy, false)).to be_true

      shell.console.should_receive(:warn).with("Will move a file:")
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :move, false)).to be_true
      shell.console.should_receive(:warn).with("Will move following entries:")
      expect(shell.copy_or_move([temp_file_1, temp_file_2], temp_dir_1, :move, false)).to be_true
    end

    it "should complain about non writeable parent directory" do
      File.open(temp_file_1, "w") {|f| f.write("OK") }

      shell.console.should_receive(:error).with("Cannot copy file {mark=bright}#{temp_file_1}{/mark} to non writable directory {mark=bright}/dev{/mark}.")
      expect(shell.copy_or_move(temp_file_1, "/dev/bovem", :copy, true, false, false)).to be_false

      shell.console.should_receive(:error).with("Cannot move file {mark=bright}#{temp_file_1}{/mark} to non writable directory {mark=bright}/dev{/mark}.")
      expect(shell.copy_or_move(temp_file_1, "/dev/bovem", :move, true, false, false)).to be_false
    end

    it "should complain about other exceptions" do
      FileUtils.stub(:cp_r).and_raise(ArgumentError.new("ERROR"))
      FileUtils.stub(:move).and_raise(ArgumentError.new("ERROR"))
      File.open(temp_file_1, "w") {|f| f.write("OK") }

      shell.console.should_receive(:error).with("Cannot copy file {mark=bright}#{temp_file_1}{/mark} to directory {mark=bright}#{File.dirname(temp_file_2)}{/mark} due to this error: [ArgumentError] ERROR.", "\n", 5)
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :copy, true, false, false)).to be_false

      shell.console.should_receive(:error).with("Cannot move file {mark=bright}#{temp_file_1}{/mark} to directory {mark=bright}#{File.dirname(temp_file_2)}{/mark} due to this error: [ArgumentError] ERROR.", "\n", 5)
      expect(shell.copy_or_move(temp_file_1, temp_file_2, :move, true, false, false)).to be_false
    end

    describe "should exit when requested to" do
      it "by calling :fatal" do
        FileUtils.stub(:cp_r).and_raise(ArgumentError.new("ERROR"))
        FileUtils.stub(:move).and_raise(ArgumentError.new("ERROR"))

        File.open(temp_file_1, "w") {|f| f.write("OK") }
        File.open(temp_file_2, "w") {|f| f.write("OK") }

        shell.console.should_receive(:fatal).with("Cannot copy file {mark=bright}#{temp_file_1}{/mark} to directory {mark=bright}/dev{/mark} due to this error: [ArgumentError] ERROR.", "\n", 5)
        expect(shell.copy_or_move(temp_file_1, "/dev/bovem", :copy, true, false, true)).to be_false

        shell.console.should_receive(:fatal).with("Cannot move file {mark=bright}#{temp_file_1}{/mark} to directory {mark=bright}/dev{/mark} due to this error: [ArgumentError] ERROR.", "\n", 5)
        expect(shell.copy_or_move(temp_file_1, "/dev/bovem", :move, true, false, true)).to be_false

        Kernel.stub(:exit).and_return(true)
        shell.console.should_receive(:error).with("Cannot copy following entries to {mark=bright}/dev{/mark}:")
        expect(shell.copy_or_move([temp_file_1, temp_file_2], "/dev", :copy, true, false, true)).to be_false

        shell.console.should_receive(:error).with("Cannot move following entries to {mark=bright}/dev{/mark}:")
        expect(shell.copy_or_move([temp_file_1, temp_file_2], "/dev", :move, true, false, true)).to be_false
      end

      it "by calling Kernel#exit" do
        File.open(temp_file_1, "w") {|f| f.write("OK") }
        File.open(temp_file_2, "w") {|f| f.write("OK") }

        Kernel.should_receive(:exit).with(-1).exactly(4).and_return(true)
        expect(shell.copy_or_move(temp_file_1, "/dev/bovem", :copy, true, false, true)).to be_false
        expect(shell.copy_or_move([temp_file_1, temp_file_2], "/dev", :copy, true, false, true)).to be_false
        expect(shell.copy_or_move(temp_file_1, "/dev/bovem", :move, true, false, true)).to be_false
        expect(shell.copy_or_move([temp_file_1, temp_file_2], "/dev", :move, true, false, true)).to be_false
      end
    end
  end

  describe "#copy" do
    it "should forward everything to #copy_or_move" do
      shell.should_receive(:copy_or_move).with("A", "B", :copy, "C", "D", "E")
      shell.copy("A", "B", "C", "D", "E")
    end
  end

  describe "#move" do
    it "should forward everything to #copy_or_move" do
      shell.should_receive(:copy_or_move).with("A", "B", :move, "C", "D", "E")
      shell.move("A", "B", "C", "D", "E")
    end
  end

  describe "#within_directory" do
    let(:target){ File.expand_path("~") }

    it "should execute block in other directory and return true" do
      owd = Dir.pwd
      dir = ""

      shell.within_directory(target) do
        expect(Dir.pwd).to eq(target)
        dir = "OK"
      end

      expect(shell.within_directory(target) { dir = "OK" }).to be_true
    end

    it "should change and restore directory" do
      owd = Dir.pwd

      shell.within_directory(target) do
        expect(Dir.pwd).to eq(target)
      end

      expect(Dir.pwd).to eq(owd)
    end

    it "should change but not restore directory" do
      owd = Dir.pwd

      shell.within_directory(target) do
        expect(Dir.pwd).to eq(target)
      end

      expect(Dir.pwd).not_to eq(target)
    end

    it "should show messages" do
      shell.console.should_receive(:info).with(/Moving into directory \{mark=bright\}(.+)\{\/mark\}/)
      shell.within_directory(target, true, true) { "OK" }
    end

    it "should return false and not execute code in case of invalid directory" do
      dir = ""

      expect(shell.within_directory("/invalid") { dir = "OK" }).to be_false
      expect(dir).to eq("")

      Dir.stub(:chdir).and_raise(ArgumentError)
      expect(shell.within_directory("/") { dir = "OK" }).to be_false

      Dir.unstub(:chdir)
      Dir.stub(:pwd).and_return("/invalid")
      expect(shell.within_directory("/") { dir = "OK" }).to be_false
    end
  end

  describe "#create_directories" do
    before(:each) do
      FileUtils.rm_r(temp_file_1) if File.exists?(temp_file_1)
      FileUtils.rm_r(temp_file_2) if File.exists?(temp_file_2)
      FileUtils.rm_r(temp_file_3) if File.exists?(temp_file_3)
      FileUtils.rm_r(temp_dir_1) if File.exists?(temp_dir_1)
      FileUtils.rm_r(temp_dir_2) if File.exists?(temp_dir_2)
    end

    after(:each) do
      FileUtils.rm_r(temp_file_1) if File.exists?(temp_file_1)
      FileUtils.rm_r(temp_file_2) if File.exists?(temp_file_2)
      FileUtils.rm_r(temp_file_3) if File.exists?(temp_file_3)
      FileUtils.rm_r(temp_dir_1) if File.exists?(temp_dir_1)
      FileUtils.rm_r(temp_dir_2) if File.exists?(temp_dir_2)
    end

    it "should create directory" do
      expect(shell.create_directories([temp_dir_1, temp_dir_2])).to be_true
      expect(shell.check(temp_dir_1, :directory)).to be_true
      expect(shell.check(temp_dir_2, :directory)).to be_true
    end

    it "should only print the list of files" do
      shell.console.should_receive(:warn).with("Will create directories:")
      FileUtils.should_not_receive(:mkdir_p)
      expect(shell.create_directories(temp_file_1, 0755, false)).to be_true
    end

    it "should complain about directory already existing" do
      shell.create_directories(temp_dir_1, 0755, true, false, false)
      shell.console.should_receive(:error).with("The directory {mark=bright}#{temp_dir_1}{/mark} already exists.")
      expect(shell.create_directories(temp_dir_1, 0755, true, false, false)).to be_false
    end

    it "should complain about paths already existing as a file." do
      File.open(temp_file_1, "w") {|f| f.write("OK") }

      shell.console.should_receive(:error).with("Path {mark=bright}#{temp_file_1}{/mark} is currently a file.")
      expect(shell.create_directories(temp_file_1, 0755, true, false, false)).to be_false
    end

    it "should complain about non writable parents" do
      shell.console.should_receive(:error).with("Cannot create following directory due to permission denied: {mark=bright}/dev/bovem{/mark}.")
      expect(shell.create_directories("/dev/bovem", 0755, true, false, false)).to be_false
    end

    it "should complain about other exceptions" do
      FileUtils.stub(:mkdir_p).and_raise(ArgumentError.new("ERROR"))
      shell.console.should_receive(:error).with("Cannot create following directories:")
      shell.console.should_receive(:write).at_least(2)
      expect(shell.create_directories(temp_dir_1, 0755, true, true, false)).to be_false
    end

    describe "should exit when requested to" do
      it "by calling :fatal" do
        shell.console.should_receive(:fatal).with("Path {mark=bright}/dev/null{/mark} is currently a file.")
        expect(shell.create_directories("/dev/null")).to be_false
      end

      it "by calling Kernel#exit" do
        FileUtils.stub(:mkdir_p).and_raise(ArgumentError.new("ERROR"))
        Kernel.should_receive(:exit).with(-1)
        expect(shell.create_directories(temp_dir_1, 0755, true, true)).to be_false
      end
    end
  end

  describe "#find" do
    let(:root) {File.expand_path(File.dirname(__FILE__) + "/../../") }

    it "it should return [] for invalid or empty directories" do
      expect(shell.find("/invalid", /rb/)).to eq([])
    end

    it "it should return every file for empty patterns" do
      files = []

      Find.find(root) do |file|
        files << file
      end

      expect(shell.find(root, nil)).to eq(files)
    end

    it "should find files basing on pattern" do
      files = []

      Find.find(root + "/lib/bovem/") do |file|
        files << file if !File.directory?(file)
      end

      expect(shell.find(root, /lib\/bovem\/.+rb/)).to eq(files)
      expect(shell.find(root, /lib\/BOVEM\/.+rb/)).to eq(files)
      expect(shell.find(root, "lib\/bovem/")).to eq(files)
      expect(shell.find(root, /lib\/BOVEM\/.+rb/, false, true)).to eq([])
    end

    it "should find files basing on extension" do
      files = []

      Find.find(root + "/lib/bovem/") do |file|
        files << file if !File.directory?(file)
      end

      expect(shell.find(root + "/lib/bovem", /rb/, true)).to eq(files)
      expect(shell.find(root + "/lib/bovem", /bovem/, true)).to eq([])
      expect(shell.find(root + "/lib/bovem", "RB", true, true)).to eq([])
    end
  end
end