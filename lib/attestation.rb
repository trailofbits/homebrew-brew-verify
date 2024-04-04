# typed: true
# frozen_string_literal: true

require "json"
require "utils/popen"

module Homebrew
  module Attestation
    COMMAND_ERROR = :command_error
    def self.check_attestation(bottle, signing_repo)
      cmd = ["gh", "attestation", "verify", bottle.cached_download, "-R", signing_repo, "--format", "json"]
      begin
        output = Utils.safe_popen_read(*cmd)
      rescue ErrorDuringExecution => e
        # TODO(joesweeney): Don't return a Hash. Use a real type or exceptions.
        return { verified: false, error: COMMAND_ERROR, message: "Command failed with status #{e}" }
      end

      begin
        json_output = JSON.parse(output)
      rescue JSON::ParserError => e
        # TODO(joesweeney): Don't return a Hash.
        return { verified: false, error: JSON::ParserError, message: "Failed to parse JSON: #{e.message}" }
      end
      is_verified = json_output.length.positive?
      # TODO(joesweeney): Don't return a Hash.
      { verified: is_verified, data: json_output }
    end
  end
end
