# encoding: utf-8
#
# This file is part of the bovem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

module Bovem
  # Exceptions for {Bovem Bovem}.
  module Errors
    # This exception is raised if a {Configuration Configuration} is invalid.
    class InvalidConfiguration < ::ArgumentError
    end

    # This exception is raised if a {Logger Logger} is invalid.
    class InvalidLogger < ::ArgumentError
    end

    # This exception is raised when something goes wrong.
    #
    # @attribute [r] target
    #   @return [Object] The target of this error.
    # @attribute [r] reason
    #   @return [Symbol] The reason of failure.
    # @attribute [r] message
    #   @return [String] A human readable message.
    class Error < ArgumentError
      attr_reader :target
      attr_reader :reason
      attr_reader :message

      # Initializes a new error
      #
      # @param target [Object] The target of this error.
      # @param reason [Symbol] The reason of failure.
      # @param message [String] A human readable message.
      def initialize(target, reason, message)
        super(message)

        @target = target
        @reason = reason
        @message = message
      end
    end
  end
end
