# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

require "spec_helper"

describe Bovem::I18n do
  let(:subject) { Bovem::I18n.new(:it, root: "bovem.shell", path: Bovem::Application::LOCALE_ROOT) }

  describe "#method_missing" do
    it "should find translation and format them" do
      expect(subject.copy_move_single_to_directory("A", "B", "C")).to eq("Impossibile eseguire A del file {mark=bright}B{/mark} in {mark=bright}C{/mark} perché è attualmente una cartella.")
    end

    it "should complain about missing translation" do
      expect { subject.foo }.to raise_error(Lazier::Exceptions::MissingTranslation, "Unable to load the translation \"bovem.shell.foo\" for the locale \"it\".")
    end
  end
end