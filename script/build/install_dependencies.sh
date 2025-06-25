#!/usr/bin/env bash

# Essentialy fails loudy
# Exit immediately if a command exits with a non-zero status (-e),
# treat unset variables as an error (-u),
# and ensure the script fails if any command in a pipeline fails (-o pipefail)
set -euo pipefail

# Function to handle errors
handle_error() {
  echo "🚨 Error: $1" >&2
  exit 1
}

echo "🔧 Starting setup and installations..."

# Install Salesforce CLI
echo "📦 Installing Salesforce CLI..."
if ! npm install @salesforce/cli --global > /dev/null 2>&1; then
  handle_error "Failed to install Salesforce CLI"
fi
sf_version=$(sf --version 2>/dev/null | head -n 1)
echo "✅ Salesforce CLI installed successfully! Version: $sf_version"

# Install sfdx-git-delta plugin
echo "🔌 Installing sfdx-git-delta plugin..."
if ! echo y | sf plugins install sfdx-git-delta > /dev/null 2>&1; then
  handle_error "Failed to install sfdx-git-delta plugin"
fi
delta_plugin_version=$(sf plugins inspect sfdx-git-delta 2>/dev/null | grep version | awk '{print $2}')
echo "✅ sfdx-git-delta plugin installed! Version: $delta_plugin_version"

# Inspect sfdx-git-delta plugin (for validation)
echo "🔍 Validating sfdx-git-delta plugin..."
if ! sf plugins inspect sfdx-git-delta > /dev/null 2>&1; then
  handle_error "Failed to inspect sfdx-git-delta plugin"
fi
echo "🔎 Plugin validation complete."

echo "🎉 All installations completed successfully!"
