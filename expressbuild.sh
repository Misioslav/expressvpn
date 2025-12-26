#!/bin/bash
set -euo pipefail

# ExpressVPN Docker Build Script
# Builds ExpressVPN image for Debian trixie-slim on amd64

usage() {
    echo "Usage: $0 <version> <repository> [tag] [action]"
    echo "Defaults: tag=latest, action=push"
    echo "Action: 'load' (local) or 'push' (to registry)"
    exit 1
}

build_image() {
    local version="$1" repository="$2" tag="$3" action="$4"
    local image_name="${repository}/expressvpn:${tag}"

    echo "Building ${tag} (trixie-slim on linux/amd64) - ${action}"

    local build_args=(
        --build-arg EXPRESSVPN_VERSION="$version"
        --build-arg DISTRIBUTION="trixie-slim"
        --platform "linux/amd64"
        -t "$image_name"
    )
    
    [[ "$action" == "push" ]] && build_args+=(--push) || build_args+=(--load)
    
    docker buildx build "${build_args[@]}" .
}

main() {
    [[ $# -lt 2 ]] && usage

    local version="$1" repository="$2" tag="${3:-latest}" action="${4:-push}"
    build_image "$version" "$repository" "$tag" "$action"

    [[ "$action" == "load" ]] && docker system prune -a -f --volumes
}

main "$@"
