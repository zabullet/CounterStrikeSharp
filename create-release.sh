#!/bin/bash

set -euo pipefail

DRY_RUN=false
CHANNEL=""

usage() {
    echo "Usage: $0 [--dry-run|-d] [--channel bleeding-edge|bleeding-edgesigs]"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --channel)
            if [[ $# -lt 2 ]]; then
                echo "Error: --channel requires a value"
                usage
            fi
            CHANNEL="$2"
            shift 2
            ;;
        *)
            echo "Error: unknown argument '$1'"
            usage
            ;;
    esac
done

if [[ "$DRY_RUN" == true ]]; then
    echo "Running in DRY-RUN mode - no changes will be pushed"
fi

if [[ -z "$CHANNEL" ]]; then
    case "$(git branch --show-current)" in
        bleeding-edge)
            CHANNEL="bleeding-edge"
            ;;
        bleeding-edge-sigs)
            CHANNEL="bleeding-edgesigs"
            ;;
        *)
            echo "Error: current branch '$(git branch --show-current)' is not a release branch."
            echo "Check out bleeding-edge or bleeding-edge-sigs, or pass --channel."
            exit 1
            ;;
    esac
fi

case "$CHANNEL" in
    bleeding-edge)
        RELEASE_BRANCH="bleeding-edge"
        ;;
    bleeding-edgesigs)
        RELEASE_BRANCH="bleeding-edge-sigs"
        ;;
    *)
        echo "Error: unknown channel '$CHANNEL'"
        echo "Expected: bleeding-edge or bleeding-edgesigs"
        exit 1
        ;;
esac

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "$RELEASE_BRANCH" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "Note: dry-run on '$CURRENT_BRANCH'. A real release must be run from '$RELEASE_BRANCH'."
    else
        echo "Error: channel '$CHANNEL' must be released from '$RELEASE_BRANCH' (current: '$CURRENT_BRANCH')."
        exit 1
    fi
fi

echo "Starting automated release process for channel: $CHANNEL"

echo "Fetching latest tags from remote..."
git fetch --tags

# Highest plain upstream release (vX.Y.Z). Fork tags and other pre-releases are ignored.
LATEST_UPSTREAM="$(git tag -l | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -V | tail -n 1 || true)"
if [[ -z "$LATEST_UPSTREAM" ]]; then
    echo "Error: no upstream tags matching vX.Y.Z were found."
    echo "Fetch them first: git fetch upstream --tags && git push origin --tags"
    exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST_UPSTREAM"
FORK_PATCH=$((PATCH + 1))
FORK_BASE="${MAJOR}.${MINOR}.${FORK_PATCH}"

# N increments for each fork release on this patch. A tag without .N counts as 0.
MAX_N=-1
while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    if [[ $tag =~ ^v${MAJOR}\.${MINOR}\.${FORK_PATCH}-${CHANNEL}(\.([0-9]+))?$ ]]; then
        if [[ -n "${BASH_REMATCH[2]:-}" ]]; then
            n="${BASH_REMATCH[2]}"
        else
            n=0
        fi
        if (( n > MAX_N )); then
            MAX_N=$n
        fi
    fi
done < <(git tag -l "v${FORK_BASE}-${CHANNEL}" "v${FORK_BASE}-${CHANNEL}.*")

if (( MAX_N < 0 )); then
    NEW_N=1
    PREVIOUS_TAG="none"
else
    NEW_N=$((MAX_N + 1))
    if (( MAX_N == 0 )); then
        PREVIOUS_TAG="v${FORK_BASE}-${CHANNEL}"
    else
        PREVIOUS_TAG="v${FORK_BASE}-${CHANNEL}.${MAX_N}"
    fi
fi

NEW_TAG="v${FORK_BASE}-${CHANNEL}.${NEW_N}"

echo "Upstream tag: v${LATEST_UPSTREAM}"
echo "New version will be: $NEW_TAG"

echo "Generating changelog with git-cliff..."
npx git-cliff -o CHANGELOG.md -t "$NEW_TAG"

if ! git diff --quiet CHANGELOG.md; then
    echo "Changelog updated successfully"

    git add CHANGELOG.md

    COMMIT_MSG="release: $NEW_TAG"
    echo "Committing changelog with message: $COMMIT_MSG"

    if [[ "$DRY_RUN" == true ]]; then
        git commit -m "$COMMIT_MSG"

        echo "Creating tag locally: $NEW_TAG"
        git tag "$NEW_TAG"

        echo "DRY-RUN: Would push commit to remote"
        echo "DRY-RUN: Would push tag to remote"
    else
        git commit -m "$COMMIT_MSG"

        echo "Pushing commit to remote..."
        git push origin "$RELEASE_BRANCH"

        echo "Creating and pushing tag: $NEW_TAG"
        git tag "$NEW_TAG"
        git push origin tag "$NEW_TAG"
    fi

    echo "Release $NEW_TAG completed successfully!"
    echo "Summary:"
    echo "   - Upstream version: v${LATEST_UPSTREAM}"
    echo "   - Previous channel tag: $PREVIOUS_TAG"
    echo "   - New version: $NEW_TAG"
    echo "   - Changelog updated: Yes"
    if [[ "$DRY_RUN" == true ]]; then
        echo "   - Commit pushed: (dry-run)"
        echo "   - Tag created and pushed: (dry-run)"
    else
        echo "   - Commit pushed: Yes"
        echo "   - Tag created and pushed: Yes"
    fi
else
    echo "No changes detected in CHANGELOG.md"
    echo "This might indicate that there are no new commits since the last release."
    exit 1
fi
