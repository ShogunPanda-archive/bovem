# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Bovem::Parser do
  let(:application) {
    Bovem::Application.new do
      command :abc do
        action do
        end

        command :def do
          action do |command|
          end
        end
      end

      option :boolean, ["b", "boolean"], help: "BOOLEAN"
      option :string, [nil, "string"], type: String, meta: "STRING", help: "STRING"
      option :integer, ["i", nil], type: Integer, help: "INTEGER"
      option :float, [nil, nil], type: Float, help: "FLOAT"
      option :array, ["a", "array"], type: Array, help: "ARRAY"
      option :choice, ["c", "choice"], type: String, help: "ARRAY", validator: ["yes", "no"]
      option :regexp, ["r", "regexp"], type: String, help: "REGEXP", validator: /yes|no/i
      option :action, ["A"] do |_, command|
        p "[OPTION] BLOCK"
      end
    end
  }

  let(:command) {
    c = Bovem::Command.new
    c.application = application
    c
  }

  describe ".smart_join" do
    it "should correctly join arrays" do
      expect(Bovem::Parser.smart_join([])).to eq("")
      expect(Bovem::Parser.smart_join(["A"], quote: nil)).to eq("A")
      expect(Bovem::Parser.smart_join(1, quote: nil)).to eq("1")
      expect(Bovem::Parser.smart_join(["A", 1], quote: nil)).to eq("A and 1")
      expect(Bovem::Parser.smart_join(["A", 1, true], quote: nil)).to eq("A, 1 and true")
      expect(Bovem::Parser.smart_join(["A", "B", "C"], separator: "-", last_separator: " and ", quote: nil)).to eq("A-B and C")
      expect(Bovem::Parser.smart_join(["A", "B", "C"], separator: "-", last_separator: "@", quote: nil)).to eq("A-B@C")
      expect(Bovem::Parser.smart_join(["A", "B", "C"], quote: "@")).to eq("@A@, @B@ and @C@")
    end
  end

  describe ".find_command" do
    it "should find commands" do
      args = ["A", "B", "C"]
      s1 = command.command("abc")
      s2 = command.command("abd")
      s1.command("def")

      expect(Bovem::Parser.find_command("abc", command, args: args)).to eq({name: "abc", args: args})
      expect(Bovem::Parser.find_command("abc:def", command, args: args)).to eq({name: "abc", args: ["def"] + args})
      expect(Bovem::Parser.find_command("abc def", command, args: args, separator: " ")).to eq({name: "abc", args: ["def"] + args})
      expect(Bovem::Parser.find_command("d", s1, args: args)).to eq({name: "def", args: args})
      expect{ Bovem::Parser.find_command("ab", command, args: args) }.to raise_error(Bovem::Errors::Error)
      expect(Bovem::Parser.find_command("abc", s2, args: args)).to be_nil
    end
  end

  describe ".parse" do
    it "should instantiate a parser and then parse" do
      expect(Bovem::Parser).to receive(:new).and_call_original
      expect_any_instance_of(Bovem::Parser).to receive(:parse).with("COMMAND", "ARGS")
      Bovem::Parser.parse("COMMAND", "ARGS")
    end
  end

  describe "#parse" do
    it "should iterate options" do
      expect(application.options).to receive(:each_pair).exactly(2)
      Bovem::Parser.parse(application, [])
    end

    it "should set good values" do
      expect(application.options["boolean"]).to receive("set").with(true)
      expect(application.options["string"]).to receive("set").with("A")
      expect(application.options["integer"]).to receive("set").with(1)
      expect(application.options["float"]).to receive("set").with(2.0)
      expect(application.options["array"]).to receive("set").with(["B", "C"])
      expect(application.options["choice"]).to receive("set").with("yes")
      expect(application.options["regexp"]).to receive("set").with("no")
      expect(application.options["action"]).to receive("execute_action")
      Bovem::Parser.parse(application, ["-b", "-s", "A", "-i", "1", "-f", "2.0", "-a", "B,C", "-c", "yes", "-r", "no", "-A"])
    end

    it "should complain about invalid or additional values" do
      expect { Bovem::Parser.parse(application, ["-b=f"]) }.to raise_error(Bovem::Errors::Error)
      expect { Bovem::Parser.parse(application, ["-s"]) }.to raise_error(Bovem::Errors::Error)
      expect { Bovem::Parser.parse(application, ["-i", "A"]) }.to raise_error(Bovem::Errors::Error)
      expect { Bovem::Parser.parse(application, ["-f", "A"]) }.to raise_error(Bovem::Errors::Error)
      expect { Bovem::Parser.parse(application, ["-c", "B"]) }.to raise_error(Bovem::Errors::Error)
      expect { Bovem::Parser.parse(application, ["-r", "C"]) }.to raise_error(Bovem::Errors::Error)
      expect { Bovem::Parser.parse(application, ["-R", "C"]) }.to raise_error(Bovem::Errors::Error)
      application.option("R", [], {required: true})
      expect { Bovem::Parser.parse(application, ["-b"]) }.to raise_error(Bovem::Errors::Error) # Because we're missing a required option
    end

    it "should complain about duplicate options" do
      application.option(:boolean2)
      expect { Bovem::Parser.parse(application, ["-b"]) }.to raise_error(Bovem::Errors::Error)
    end

    it "should return the command to execute" do
      expect(Bovem::Parser.parse(application, ["a", "OTHER"])).to eq({name: "abc", args: ["OTHER"]})
      expect(Bovem::Parser.parse(application, ["ab:d", "OTHER"])).to eq({name: "abc", args: ["d", "OTHER"]})
      expect(Bovem::Parser.parse(application, ["abc", "d", "OTHER"])).to eq({name: "abc", args: ["d", "OTHER"]})
      expect(Bovem::Parser.parse(application, ["d", "OTHER"])).to eq(nil)

      application.clear_options
      expect(Bovem::Parser.parse(application, ["a", "OTHER"])).to eq({name: "abc", args: ["OTHER"]})
      expect(Bovem::Parser.parse(application, ["d:d", "OTHER"])).to eq(nil)
      expect(Bovem::Parser.parse(application, ["d d", "OTHER"])).to eq(nil)
      expect(Bovem::Parser.parse(application, ["d", "d", "OTHER"])).to eq(nil)
    end
  end
end