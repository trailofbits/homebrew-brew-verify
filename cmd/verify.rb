# frozen_string_literal: true

require "formula"
require "cli/parser"
require "cmd/fetch"

module Homebrew
  extend Fetch

  def self.verify_args
    Homebrew::CLI::Parser.new do
      description <<~EOS
        Verify the build provenance of bottles using GitHub's attestation tools.
        This is done by first fetching the given bottles, and then verifying
        their provenance.

        Note that this command depends on the GitHub CLI and the gh-attestation extension:
        https://github.com/github-early-access/gh-attestation?tab=readme-ov-file#installation

        Follow the instructions there to install.
      EOS
      switch "--formula", "--formulae",
             description: "List only formulae, or treat all named arguments as formulae."
      switch "--cask", "--casks",
             description: "List only casks, or treat all named arguments as casks."
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
      conflicts "--formula", "--cask"
      conflicts "--os", "--bottle-tag"
      conflicts "--arch", "--bottle-tag"
      named_args [:formula], min: 1
    end
  end

  def self.verify
    args = verify_args.parse
    if args.cask?
      opoo "Can only verify bottles, not casks."
      return
    end
    bucket = if args.deps?
      args.named.to_formulae_and_casks.flat_map do |formula_or_cask|
        case formula_or_cask
        when Formula
          formula = formula_or_cask
          [formula, *formula.recursive_dependencies.map(&:to_formula)]
        else
          formula_or_cask
        end
      end
    else
      args.named.to_formulae_and_casks
    end.uniq
    os_arch_combinations = args.os_arch_combinations
    bucket.each do |formula_or_cask|
      case formula_or_cask
      when Formula
        formula = T.cast(formula_or_cask, Formula)
        os_arch_combinations.each do |os, arch|
          SimulateSystem.with os: os, arch: arch do
            bottle_tag = if (bottle_tag = args.bottle_tag&.to_sym)
              Utils::Bottles::Tag.from_symbol(bottle_tag)
            else
              Utils::Bottles::Tag.new(system: os, arch: arch)
            end

            bottle = formula.bottle_for_tag(bottle_tag)

            if bottle.nil?
              opoo "Bottle for tag #{bottle_tag.to_sym.inspect} is unavailable."
              next
            end
            formula.fetch_bottle_tab
            fetch_formula(bottle, args: args)
            puts formula.cached_download
            safe_system "gh", "attestation", "verify", bottle.cached_download, "-R", "Homebrew/homebrew-core"
          end
        end
      else
        opoo "Can only verify bottles, not casks. #{formula_or_cask} is a cask."
        next
      end
    end
  end
end
