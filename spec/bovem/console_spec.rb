# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Bovem::Console do
  let(:console) {
    c = ::Bovem::Console.new
    c.i18n = :en
    c
  }

  before(:each) do
    ENV["TERM"] = "xterm-256color"
    Kernel.stub(:puts).and_return(nil)
  end

  describe ".instance" do
    it "should always return the same instance" do
      instance = ::Bovem::Console.instance
      expect(::Bovem::Console.instance).to be(instance)
    end
  end

  describe ".parse_style" do
    it "should correctly parse styles" do
      expect(::Bovem::Console.parse_style("red")).to eq("\e[31m")
      expect(::Bovem::Console.parse_style("bg_green")).to eq("\e[42m")
      expect(::Bovem::Console.parse_style("bright")).to eq("\e[1m")
      expect(::Bovem::Console.parse_style("FOO")).to eq("")
      expect(::Bovem::Console.parse_style(nil)).to eq("")
      expect(::Bovem::Console.parse_style(["A"])).to eq("")
      expect(::Bovem::Console.parse_style("-")).to eq("")
    end
  end

  describe ".replace_markers" do
    it "should correct replace markers" do
      expect(::Bovem::Console.replace_markers("{mark=red}RED{/mark}")).to eq("\e[31mRED\e[0m")
      expect(::Bovem::Console.replace_markers("{mark=red}RED {mark=green}GREEN{/mark}{/mark}")).to eq("\e[31mRED \e[32mGREEN\e[31m\e[0m")
      expect(::Bovem::Console.replace_markers("{mark=red}RED {mark=bright-green}GREEN {mark=blue}BLUE{mark=NONE}RED{/mark}{/mark}{/mark}{/mark}")).to eq("\e[31mRED \e[1m\e[32mGREEN \e[34mBLUERED\e[1m\e[32m\e[31m\e[0m")
      expect(::Bovem::Console.replace_markers("{mark=bg_red}RED{mark=reset}NORMAL{/mark}{/mark}")).to eq("\e[41mRED\e[0mNORMAL\e[41m\e[0m")
      expect(::Bovem::Console.replace_markers("{mark=NONE}RED{/mark}")).to eq("RED")
    end

    it "should clean up markers if requested" do
      expect(::Bovem::Console.replace_markers("{mark=red}RED{/mark}", true)).to eq("RED")
    end
  end

  describe ".execute_command" do
    it "should execute a command" do
      expect(::Bovem::Console.execute("echo OK")).to eq("OK\n")
    end
  end

  describe ".min_banner_length" do
    it "should return a number" do
      expect(::Bovem::Console.min_banner_length).to be_a(Fixnum)
    end
  end

  describe "#initialize" do
    it "should correctly set defaults" do
      expect(console.indentation).to eq(0)
      expect(console.indentation_string).to eq(" ")
    end
  end

  describe "#line_width" do
    it "should return a Fixnum greater than 0" do
      w = console.line_width
      expect(w).to be_a(Fixnum)
      expect(w >= 0).to be_true
    end

    it "should use $stdin.winsize if available" do
      $stdin.should_receive(:winsize)
      console.line_width
    end
  end

  describe "#set_indentation" do
    it "should correctly set indentation" do
      expect(console.indentation).to eq(0)
      console.set_indentation(5)
      expect(console.indentation).to eq(5)
      console.set_indentation(-2)
      expect(console.indentation).to eq(3)
      console.set_indentation(10, true)
      expect(console.indentation).to eq(10)
    end
  end

  describe "#reset_indentation" do
    it "should correctly reset indentation" do
      console.set_indentation(5)
      expect(console.indentation).to eq(5)
      console.reset_indentation
      expect(console.indentation).to eq(0)
    end
  end

  describe "#with_indentation" do
    it "should correctly wrap indentation" do
      console.set_indentation(5)
      expect(console.indentation).to eq(5)

      console.with_indentation(7) do
        expect(console.indentation).to eq(12)
      end
      expect(console.indentation).to eq(5)

      console.with_indentation(3, true) do
        expect(console.indentation).to eq(3)
      end
      expect(console.indentation).to eq(5)
    end
  end

  describe "#wrap" do
    it "should correct wrap text" do
      message = "  ABC__DEF GHI JKL"
      expect(console.wrap(message, 2)).to eq("ABC__DEF\nGHI\nJKL")
      expect(console.wrap(message, 3)).to eq("ABC__DEF\nGHI\nJKL")
      expect(console.wrap(message, 4)).to eq("ABC__DEF\nGHI\nJKL")
      expect(console.wrap(message, 5)).to eq("ABC__DEF\nGHI\nJKL")
      expect(console.wrap(message, 20)).to eq("  ABC__DEF GHI JKL")

      expect(console.wrap(message, nil)).to eq(message)
      expect(console.wrap(message, -1)).to eq(message)
    end

    it "should work well with #indent" do
      message = "AB CD"
      console.set_indentation(2)
      expect(console.wrap(console.indent(message), 2)).to eq("AB\nCD")
    end
  end

  describe "#indent" do
    it "should correctly indent messages" do
      message = "ABC\nCDE"
      console.set_indentation(2)

      expect(console.indent(message)).to eq("  ABC\n  CDE")
      expect(console.indent(message, -1)).to eq(" ABC\n CDE")
      expect(console.indent(message, 1)).to eq("   ABC\n   CDE")
      expect(console.indent(message, true, "D")).to eq("  ABC\nCD  E")

      expect(console.indent(message, 0)).to eq(message)
      expect(console.indent(message, nil)).to eq(message)
      expect(console.indent(message, false)).to eq(message)
      expect(console.indent(message, "A")).to eq(message)
    end
  end

  describe "#format" do
    it "should apply modifications to the message" do
      message = "ABC"
      console.set_indentation(2)
      expect(console.format(message, "\n", false)).to eq("ABC\n")
      expect(console.format(message, "A")).to eq("  ABCA")
      expect(console.format(message, "A", 3)).to eq("     ABCA")
      expect(console.format(message, "A", 3, 4)).to eq("     ABCA")
      expect(console.format("{mark=red}ABC{/mark}", "\n", true, true, true)).to eq("  ABC\n")
    end
  end

  describe "#replace_markers" do
    it "should just forwards to .replace_markers" do
      ::Bovem::Console.should_receive(:replace_markers).with("A", "B")
      console.replace_markers("A", "B")
    end
  end

  describe "#format_right" do
    it "should correctly align messages" do
      message = "ABCDE"
      extended_message = "ABC\e[AD\e[3mE"
      console.stub(:line_width).and_return(80)

      expect(console.format_right(message)).to eq("\e[A\e[0G\e[#{75}CABCDE")
      expect(console.format_right(message, 10)).to eq("\e[A\e[0G\e[#{5}CABCDE")
      expect(console.format_right(extended_message)).to eq("\e[A\e[0G\e[#{75}CABC\e[AD\e[3mE")
      expect(console.format_right(message, nil, false)).to eq("\e[0G\e[#{75}CABCDE")
      console.stub(:line_width).and_return(10)
      expect(console.format_right(message)).to eq("\e[A\e[0G\e[#{5}CABCDE")
    end
  end

  describe "#write" do
    it "should call #format" do
      console.should_receive(:format).with("A", "B", "C", "D", "E")
      console.write("A", "B", "C", "D", "E")
    end
  end

  describe "#write_banner_aligned" do
    it "should call #min_banner_length and #format" do
      ::Bovem::Console.should_receive(:min_banner_length).and_return(1)
      console.should_receive(:format).with("    A", "B", "C", "D", "E")
      console.write_banner_aligned("A", "B", "C", "D", "E")
    end
  end

  describe "#get_banner" do
    it "should correctly format arguments" do
      expect(console.get_banner("LABEL", "red")).to eq("{mark=blue}[{mark=red}LABEL{/mark}]{/mark}")
      expect(console.get_banner("LABEL", "red", true)).to eq("{mark=red}[{mark=red}LABEL{/mark}]{/mark}")
      expect(console.get_banner("LABEL", "red", false, "yellow")).to eq("{mark=yellow}[{mark=red}LABEL{/mark}]{/mark}")
      expect(console.get_banner("LABEL", "red", false, "blue", nil)).to eq("{mark=blue}{mark=red}LABEL{/mark}{/mark}")
      expect(console.get_banner("LABEL", "red", false, "blue", "A")).to eq("{mark=blue}A{mark=red}LABEL{/mark}{/mark}")
      expect(console.get_banner("LABEL", "red", false, "blue", ["A", "B"])).to eq("{mark=blue}A{mark=red}LABEL{/mark}B{/mark}")
    end
  end

  describe "#info" do
    it "should forward everything to #get_banner" do
      console.should_receive(:get_banner).with("I", "bright cyan", false).at_least(1).and_return("")
      console.info("OK", "\n", true, false, false, false, false, false)
      console.should_receive(:get_banner).with("I", "bright cyan", true).at_least(1).and_return("")
      console.info("OK", "\n", true, false, false, false, true, false)
    end

    it "should forward everything to #write" do
      console.should_receive(:write).with(/.+/, "B", "C", "D", "E", false)
      console.info("A", "B", "C", "D", "E", "F", "G", false)
    end
  end

  describe "#begin" do
    it "should forward everything to #get_banner" do
      console.should_receive(:get_banner).with("*", "bright green", false).at_least(1).and_return("")
      console.begin("OK", "\n", true, false, false, false, false, false)
    end

    it "should forward everything to #write" do
      console.should_receive(:write).with(/.+/, "B", "C", "D", "E", false)
      console.begin("A", "B", "C", "D", "E", "F", "G", false)
    end
  end

  describe "#warn" do
    it "should forward everything to #get_banner" do
      console.should_receive(:get_banner).with("W", "bright yellow", false).at_least(1).and_return("")
      console.warn("OK", "\n", true, false, false, false, false, false)
      console.should_receive(:get_banner).with("W", "bright yellow", true).at_least(1).and_return("")
      console.warn("OK", "\n", true, false, false, false, true, false)
    end

    it "should forward everything to #write" do
      console.should_receive(:write).with(/.+/, "B", "C", "D", "E", false)
      console.warn("A", "B", "C", "D", "E", "F", "G", false)
    end
  end

  describe "#error" do
    it "should forward everything to #get_banner" do
      console.should_receive(:get_banner).with("E", "bright red", false).at_least(1).and_return("")
      console.error("OK", "\n", true, false, false, false, false, false)
      console.should_receive(:get_banner).with("E", "bright red", true).at_least(1).and_return("")
      console.error("OK", "\n", true, false, false, false, true, false)
    end

    it "should forward everything to #write" do
      console.should_receive(:write).with(/.+/, "B", "C", "D", "E", false)
      console.error("A", "B", "C", "D", "E", "F", "G", false)
    end
  end

  describe "#fatal" do
    it "should forward anything to #error" do
      Kernel.stub(:exit).and_return(true)
      console.should_receive(:error).with("A", "B", "C", "D", "E", "F", "G", false)
      console.fatal("A", "B", "C", "D", "E", "F", "G", "H", false)
    end

    it "should call abort with the right error code" do
      Kernel.stub(:exit).and_return(true)

      Kernel.should_receive(:exit).with(-1).exactly(2)
      console.fatal("A", "B", "C", "D", "E", "F", "G", -1, false)
      console.fatal("A", "B", "C", "D", "E", "F", "G", "H", false)
    end
  end

  describe "#debug" do
    it "should forward everything to #get_banner" do
      console.should_receive(:get_banner).with("D", "bright magenta", false).at_least(1).and_return("")
      console.debug("OK", "\n", true, false, false, false, false, false)
      console.should_receive(:get_banner).with("D", "bright magenta", true).at_least(1).and_return("")
      console.debug("OK", "\n", true, false, false, false, true, false)
    end

    it "should forward everything to #write" do
      console.should_receive(:write).with(/.+/, "B", "C", "D", "E", false)
      console.debug("A", "B", "C", "D", "E", "F", "G", false)
    end
  end

  describe "#status" do
    it "should get the right status" do
      expect(console.status(:ok, false, true, false)).to eq({label: " OK ", color: "bright green"})
      expect(console.status(:pass, false, true, false)).to eq({label: "PASS", color: "bright cyan"})
      expect(console.status(:warn, false, true, false)).to eq({label: "WARN", color: "bright yellow"})
      expect(console.status(:fail, false, true, false)).to eq({label: "FAIL", color: "bright red"})
      expect(console.status("NO", false, true, false)).to eq({label: " OK ", color: "bright green"})
      expect(console.status(nil, false, true, false)).to eq({label: " OK ", color: "bright green"})
    end

    it "should create the banner" do
      console.should_receive(:get_banner).with(" OK ", "bright green").and_return("")
      console.status(:ok)
    end

    it "should format correctly" do
      console.should_receive(:format_right).with(/.+/, true, true, false)
      console.status(:ok, false, true)
      console.should_receive(:format).with(/.+/, "\n", true, true, false)
      console.status(:ok, false, true, false)
    end
  end

  describe "#read" do
    it "should show a prompt" do
      $stdin.stub(:gets).and_return("VALUE\n")

      prompt = "PROMPT"
      Kernel.should_receive(:print).with("Please insert a value: ")
      console.read(true)
      Kernel.should_receive(:print).with(prompt + ": ")
      console.read(prompt)
      Kernel.should_not_receive("print")
      console.read(nil)
    end

    it "should read a value or a default" do
      $stdin.stub(:gets).and_return("VALUE\n")
      expect(console.read(nil, "DEFAULT")).to eq("VALUE")
      $stdin.stub(:gets).and_return("\n")
      expect(console.read(nil, "DEFAULT")).to eq("DEFAULT")
    end

    it "should return the default value if the user quits" do
      $stdin.stub(:gets).and_raise(Interrupt)
      expect(console.read(nil, "DEFAULT")).to eq("DEFAULT")
    end

    it "should validate against an object or array validator" do
      count = 0

      $stdin.stub(:gets) do
        if count == 0 then
          count += 1
          "2\n"
        else
          raise Interrupt
        end
      end

      console.should_receive(:write).with("Sorry, your reply was not understood. Please try again.", false, false).exactly(4)
      count = 0
      console.read(nil, nil, "A")
      count = 0
      console.read(nil, nil, "1")
      count = 0
      console.read(nil, nil, "nil")
      count = 0
      console.read(nil, nil, ["A", 1])
    end

    it "should validate against an regexp validator" do
      count = 0

      $stdin.stub(:gets) do
        if count == 0 then
          count += 1
          "2\n"
        else
          raise Interrupt
        end
      end

      console.should_receive(:write).with("Sorry, your reply was not understood. Please try again.", false, false)
      console.read(nil, nil, /[abc]/)
    end

    it "should hide echo to the user when the terminal shows echo" do
      $stdin.should_receive(:noecho).and_return("VALUE")
      console.read(nil, nil, nil, false)
    end
  end

  describe "#task" do
    it "should not print the message by default" do
      console.should_not_receive("begin")
      console.task { :ok }
    end

    it "should print the message and indentate correctly" do
      console.should_receive(:begin).with("A", "B", "C", "D", "E", "F", "G")
      console.should_receive(:with_indentation).with("H", "I")
      console.task("A", "B", "C", "D", "E", "F", "G", "H", "I") { :ok }
    end

    it "should execute the given block" do
      ::Bovem::Console.should_receive(:foo)
      console.task { ::Bovem::Console.foo }
    end

    it "should write the correct status" do
      console.stub(:begin)
      console.should_receive(:status).with(:ok, false)
      console.task("OK") { :ok }
      console.should_receive(:status).with(:fail, false)
      expect { console.task("") { :fatal }}.to raise_error(SystemExit)
    end

    it "should abort correctly" do
      expect { console.task { [:fatal, -1] }}.to raise_error(SystemExit)
    end
  end
end