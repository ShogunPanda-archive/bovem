# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Bovem::Errors::Error do
  describe "#initialize" do
    it "copies attributes" do
      error = Bovem::Errors::Error.new("A", "B", "C")
      expect(error.target).to eq("A")
      expect(error.reason).to eq("B")
      expect(error.message).to eq("C")
    end
  end
end
