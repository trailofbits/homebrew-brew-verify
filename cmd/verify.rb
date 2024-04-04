# typed: true
# frozen_string_literal: true

require "abstract_command"
require "formula"
require "json"
require "date"

# The `Homebrew` namespace.
module Homebrew
  module Cmd
    COMMAND_ERROR = :command_error

    class VerifyCmd < AbstractCommand
      cmd_args do
        description <<~EOS
          Verify the build provenance of bottles using GitHub's attestation tools.
          This is done by first fetching the given bottles, and then verifying
          their provenance.

          Note that this command depends on the GitHub CLI. Run `brew install gh`.
        EOS
        switch "--formula", "--formulae",
               description: "List only formulae, or treat all named arguments as formulae."
        flag   "--os=",
               description: "Download for the given operating system." \
                            "(Pass `all` to download for all operating systems.)"
        flag   "--arch=",
               description: "Download for the given CPU architecture." \
                            "(Pass `all` to download for all architectures.)"
        flag   "--bottle-tag=",
               description: "Download a bottle for given tag."
        switch "--deps",
               description: "Also download dependencies for any listed <formula>."
        switch "-f", "--force",
               description: "Remove a previously cached version and re-fetch."
        switch "-j", "--json",
               description: "Return JSON for the attestation data for each bottle."
        conflicts "--os", "--bottle-tag"
        conflicts "--arch", "--bottle-tag"
        named_args [:formula], min: 1
      end

      sig { override.void }
      def run
        bucket = if args.deps?
          args.named.to_formulae.flat_map do |formula|
            [formula, *formula.recursive_dependencies.map(&:to_formula)]
          end
        else
          args.named.to_formulae
        end.uniq

        os_arch_combinations = args.os_arch_combinations
        json_results = []
        bucket.each do |formula|
          os_arch_combinations.each do |os, arch|
            SimulateSystem.with(os:, arch:) do
              bottle_tag = if (bottle_tag = args.bottle_tag&.to_sym)
                Utils::Bottles::Tag.from_symbol(bottle_tag)
              else
                Utils::Bottles::Tag.new(system: os, arch:)
              end

              bottle = formula.bottle_for_tag(bottle_tag)

              if bottle.nil?
                opoo "Bottle for tag #{bottle_tag.to_sym.inspect} is unavailable."
                next
              end
              bottle.fetch
              result = check_attestation(bottle, "Homebrew/homebrew-core")
              if result[:verified]
                if args.json?
                  json_results.push(result[:data])
                else
                  ohai "Verified #{bottle.name} with tag #{bottle_tag}."
                end
              else
                case result[:error]
                when JSON::ParserError
                  opoo "#{bottle.name} with tag #{bottle_tag} returned invalid json: #{result[:message]}"
                  next
                when COMMAND_ERROR
                  opoo "#{bottle.name} with tag #{bottle_tag} unverified, checking backfill signature."
                  backup_result = check_attestation(bottle, "trailofbits/homebrew-brew-verify")
                  if backup_result[:verified]
                    timestamp = backup_result.dig(:data, 0, "verificationResult", "verifiedTimestamps", 0,
                                                  "timestamp")
                    if timestamp.nil?
                      opoo "Unable to verify #{bottle.name} with tag #{bottle_tag} " \
                           "because json does not have signature timestamp in expected location."
                      next
                    end
                    parsed_timestamp = DateTime.parse(timestamp)
                    # Backfilled signatures all occured before this date so if we find
                    # a backfilled signature after this date, we should disregard it.
                    last_signature_date = DateTime.new(2024, 3, 14)
                    if parsed_timestamp < last_signature_date
                      if args.json?
                        json_results.push(backup_result[:data])
                      else
                        ohai "Verified #{bottle.name} with tag #{bottle_tag} using backfill signature."
                      end
                    else
                      opoo "Unable to verify #{bottle.name} with tag #{bottle_tag}. " \
                           "Backfilled signature dated after last backfill date."
                    end
                  end
                end
              end
            end
          end
        end
        return unless args.json?

        puts json_results.to_json
      end

      # TODO(joesweeney): Move to separate `lib/attestation.rb`.
      def check_attestation(bottle, signing_repo)
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
end
