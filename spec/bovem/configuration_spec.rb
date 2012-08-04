# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2012 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Bovem::Configuration do
  class BaseConfiguration < Bovem::Configuration
    attr_accessor :property
  end

  let(:log_file) { "/tmp/bovem-test-log-#{Time.now.strftime("%Y%m%d-%H:%M:%S")}" }
  let(:test_prefix) { "/tmp/bovem-test-#{Time.now.strftime("%Y%m%d-%H:%M:%S")}" }

  describe "#initialize" do
    it "reads a valid configuration file" do
      file = ::File.open("#{test_prefix}", "w") {|f| f.write("config.property = 1234") }

      config = BaseConfiguration.new(test_prefix)
      expect(config.property).to eq(1234)
      File.unlink(test_prefix)
    end

    it "reject an invalid configuration" do
      file1 = ::File.open("#{test_prefix}-1", "w") {|f| f.write("config.property = ") }
      file2 = ::File.open("#{test_prefix}-2", "w") {|f| f.write("config.non_property = 1234") }

      expect { config = BaseConfiguration.new("#{test_prefix}-1")}.to raise_error(Bovem::Errors::InvalidConfiguration)
      expect { config = BaseConfiguration.new("#{test_prefix}-2")}.to raise_error(Bovem::Errors::InvalidConfiguration)

      File.unlink("#{test_prefix}-1")
      File.unlink("#{test_prefix}-2")
    end

    it "allows overrides" do
      file = ::File.open("#{test_prefix}", "w") {|f| f.write("config.property = 1234") }

      config = BaseConfiguration.new(test_prefix, {:property => 5678, :non_property => 1234})
      expect(config.property).to eq(5678)

      File.unlink(test_prefix)
    end
  end
end