# typed: true
# frozen_string_literal: true

require "json"

module Homebrew
  module Attestation
    COMMAND_ERROR = :command_error
    # TODO(joesweeney): Move to separate `lib/attestation.rb`.
    def self.check_attestation(bottle, signing_repo)
      cmd = "gh attestation verify #{bottle.cached_download} -R #{signing_repo} --format json 2>/dev/null"
      output = IO.popen(cmd, &:read)
      exit_status = $CHILD_STATUS.exitstatus
      if exit_status != 0
        # TODO(joesweeney): Don't return a Hash. Use a real type or exceptions.
        return { verified: false, error: COMMAND_ERROR, message: "Command failed with status #{exit_status}" }
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
