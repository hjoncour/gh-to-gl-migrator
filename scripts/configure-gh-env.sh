#!/usr/bin/env bash
set -euo pipefail

ask_yes_no() {
  local prompt="$1" response lowered
  while true; do
    read -r -p "$prompt [y/n]: " response
    lowered="$(printf '%s' "$response" | tr '[:upper:]' '[:lower:]')"
    case "$lowered" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Please answer with y or n." ;;
    esac
  done
}

require_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) not found in PATH." >&2
    exit 1
  fi
}

require_gh_auth() {
  if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub CLI is not authenticated. Run 'gh auth login' or export GH_TOKEN." >&2
    exit 1
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

main() {
  require_gh
  require_gh_auth

  if ! ask_yes_no "Add env secrets and variables"; then
    echo "Nothing to do."
    return 0
  fi

  local repo_input scope_args=()
  if repo_input="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"; then
    echo "Using GitHub repository: $repo_input"
  else
    read -r -p "Unable to detect repository automatically. Enter GitHub repository (owner/name): " repo_input
    repo_input="$(trim "$repo_input")"
    if [[ -z "$repo_input" ]]; then
      echo "Error: repository cannot be empty." >&2
      exit 1
    fi
    if [[ "$repo_input" == *"://"* ]]; then
      echo "Error: Provide the GitHub repository as owner/name (e.g. octo-org/migrator), not a URL." >&2
      exit 1
    fi
    if [[ ! "$repo_input" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
      echo "Error: Repository must be in the format owner/name (e.g. octo-org/migrator)." >&2
      exit 1
    fi
  fi

  scope_args=(--repo "$repo_input")

  if ask_yes_no "Add PAT secret for GitLab"; then
    local pat
    while true; do
      read -r -s -p "Enter GitLab PAT (input hidden): " pat
      echo
      pat="$(trim "$pat")"
      if [[ -z "$pat" ]]; then
        echo "PAT cannot be empty."
        continue
      fi
      gh secret set GITLAB_TOKEN "${scope_args[@]}" --app actions --body "$pat"
      unset pat
      echo "Secret GITLAB_TOKEN configured."
      break
    done
  else
    echo "Skipping PAT secret."
  fi

  if ask_yes_no "Add target GitLab repository variable"; then
    local gitlab_input normalized_repo
    read -r -p "Enter GitLab repository (gitlab.com/group/project or https://gitlab.com/group/project): " gitlab_input
    gitlab_input="$(trim "$gitlab_input")"
    if [[ "$gitlab_input" =~ ^https?://gitlab\.com/[^/]+/[^/]+$ ]]; then
      normalized_repo="$gitlab_input"
    elif [[ "$gitlab_input" =~ ^gitlab\.com/[^/]+/[^/]+$ ]]; then
      normalized_repo="$gitlab_input"
    else
      echo "Warning: value does not match gitlab.com/{group}/{project}; storing as provided."
      normalized_repo="$gitlab_input"
    fi
    gh variable set GITLAB_REPO "${scope_args[@]}" --body "$normalized_repo"
    echo "Variable GITLAB_REPO configured."
  else
    echo "Skipping target repository variable."
  fi

  echo "Done."
}

main "$@"
