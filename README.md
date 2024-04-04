# `brew verify`

This is a command-only tap for the `brew verify` command, pending its
integration into upstream `brew`.

## Usage

```bash
brew tap trailofbits/brew-verify
brew verify --help
```

# Repo Directories

- `cmd/`: Contains `verify.rb`, the code implementing `brew verify`.
- `scripts/`: Contains assorted scripts and files used to backfill signatures
that had not yet been signed by Homebrew, now unused and kept as artifacts.
