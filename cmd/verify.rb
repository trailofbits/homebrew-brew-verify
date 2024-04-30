# typed: true
# frozen_string_literal: true

require "abstract_command"
require "formula"
require "date"
require "attestation"

# The `Homebrew` namespace.
module Homebrew
  module Cmd
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
              attestation = Homebrew::Attestation.check_core_attestation bottle
              json_results.push(attestation)
            end
          end
        end

        puts json_results.to_json if args.json?
      end
    end
  end
end
