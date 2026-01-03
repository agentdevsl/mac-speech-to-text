#!/bin/bash
# Fix pre-commit config for SwiftLint 0.62+
# The 'autocorrect' subcommand was replaced with '--fix' flag

sed -i 's/swiftlint autocorrect --quiet/swiftlint --fix --quiet/' .pre-commit-config.yaml
echo "Updated .pre-commit-config.yaml: swiftlint autocorrect -> swiftlint --fix"
