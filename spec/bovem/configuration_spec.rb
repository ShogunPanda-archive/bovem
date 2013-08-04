# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Bovem::Configuration do
  class BaseConfiguration < Bovem::Configuration
    property :property
  end

  let(:log_file) { "/tmp/bovem-test-log-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }
  let(:test_prefix) { "/tmp/bovem-test-#{Time.now.strftime("%Y%m%d-%H%M%S")}" }

  describe "#parse" do
    it "reads a valid configuration file" do
      ::File.open(test_prefix, "w") {|f| f.write("config.property = 1234") }

      config = BaseConfiguration.new(test_prefix)
      expect(config.property).to eq(1234)
      File.unlink(test_prefix)
    end

    it "reject a missing or unreadable file" do
      expect { BaseConfiguration.new("/non-existing")}.to raise_error(Bovem::Errors::InvalidConfiguration)
    end

    it "reject an invalid configuration" do
      ::File.open("#{test_prefix}-1", "w") {|f| f.write("config.property = ") }
      ::File.open("#{test_prefix}-2", "w") {|f| f.write("config.non_property = 1234") }

      expect { BaseConfiguration.new("#{test_prefix}-1")}.to raise_error(Bovem::Errors::InvalidConfiguration)
      expect { BaseConfiguration.new("#{test_prefix}-2")}.to raise_error(Bovem::Errors::InvalidConfiguration)

      File.unlink("#{test_prefix}-1")
      File.unlink("#{test_prefix}-2")
    end

    it "allows overrides" do
      ::File.open("#{test_prefix}", "w") {|f| f.write("config.property = 1234") }

      config = BaseConfiguration.new(test_prefix, {property: 5678, non_property: 1234})
      expect(config.property).to eq(5678)

      File.unlink(test_prefix)
    end
  end
end