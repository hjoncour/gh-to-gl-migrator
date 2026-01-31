#!/usr/bin/env bash
# Keychain helper for storing/retrieving GitLab tokens securely
# Supports macOS Keychain and Linux secret-service (libsecret)

set -euo pipefail

SERVICE_NAME="ghmirror"
ACCOUNT_NAME="gitlab-token"

# Detect OS and available tools
get_keychain_backend() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif command -v secret-tool >/dev/null 2>&1; then
    echo "libsecret"
  else
    echo "none"
  fi
}

# Store token in keychain
keychain_store() {
  local token="$1"
  local host="${2:-gitlab.com}"
  local backend
  backend="$(get_keychain_backend)"

  case "$backend" in
    macos)
      # Delete existing entry first (ignore errors)
      security delete-generic-password -s "$SERVICE_NAME" -a "${ACCOUNT_NAME}-${host}" 2>/dev/null || true
      # Add new entry
      security add-generic-password -s "$SERVICE_NAME" -a "${ACCOUNT_NAME}-${host}" -w "$token" -U
      echo "Token stored in macOS Keychain"
      ;;
    libsecret)
      echo "$token" | secret-tool store --label="ghmirror GitLab token for ${host}" \
        service "$SERVICE_NAME" account "${ACCOUNT_NAME}-${host}"
      echo "Token stored in secret-service"
      ;;
    *)
      echo "Warning: No secure storage available. Token not saved locally." >&2
      return 1
      ;;
  esac
}

# Retrieve token from keychain
keychain_get() {
  local host="${1:-gitlab.com}"
  local backend
  backend="$(get_keychain_backend)"

  case "$backend" in
    macos)
      security find-generic-password -s "$SERVICE_NAME" -a "${ACCOUNT_NAME}-${host}" -w 2>/dev/null
      ;;
    libsecret)
      secret-tool lookup service "$SERVICE_NAME" account "${ACCOUNT_NAME}-${host}" 2>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

# Delete token from keychain
keychain_delete() {
  local host="${1:-gitlab.com}"
  local backend
  backend="$(get_keychain_backend)"

  case "$backend" in
    macos)
      security delete-generic-password -s "$SERVICE_NAME" -a "${ACCOUNT_NAME}-${host}" 2>/dev/null || true
      echo "Token removed from macOS Keychain"
      ;;
    libsecret)
      secret-tool clear service "$SERVICE_NAME" account "${ACCOUNT_NAME}-${host}" 2>/dev/null || true
      echo "Token removed from secret-service"
      ;;
    *)
      echo "No secure storage available" >&2
      return 1
      ;;
  esac
}

# Check if token exists in keychain
keychain_has() {
  local host="${1:-gitlab.com}"
  keychain_get "$host" >/dev/null 2>&1
}

# Main entry point for CLI usage
main() {
  local cmd="${1:-}"
  local host="${2:-gitlab.com}"

  case "$cmd" in
    store)
      local token
      read -r -s -p "Enter GitLab token to store: " token
      echo
      keychain_store "$token" "$host"
      ;;
    get)
      keychain_get "$host"
      ;;
    delete)
      keychain_delete "$host"
      ;;
    has)
      if keychain_has "$host"; then
        echo "Token found for $host"
        return 0
      else
        echo "No token found for $host"
        return 1
      fi
      ;;
    backend)
      get_keychain_backend
      ;;
    *)
      cat <<EOF
Usage: keychain.sh <command> [host]

Commands:
  store [host]   Store a GitLab token (prompts for input)
  get [host]     Retrieve stored token
  delete [host]  Remove stored token
  has [host]     Check if token exists
  backend        Show which keychain backend is available

Host defaults to gitlab.com
EOF
      ;;
  esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
