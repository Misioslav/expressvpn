#!/bin/bash
set -euo pipefail

# ExpressVPN Docker Build Script
# Builds ExpressVPN images for multiple distributions and platforms

usage() {
    echo "Usage: $0 <version> <repository> [distribution] [platform] [package_platform] [tag] [action]"
    echo "Defaults: distribution=trixie-slim, platform=linux/amd64, package_platform=amd64, tag=latest, action=load"
    echo "Use 'matrix' as distribution to build all platforms"
    echo "Action: 'load' (local) or 'push' (to registry)"
    exit 1
}

build_image() {
    local version="$1" repository="$2" distribution="$3" platform="$4" package_platform="$5" tag="$6" action="$7"
    local image_name="${repository}/expressvpn:${tag}"
    
    echo "Building ${tag} (${distribution} on ${platform}) - ${action}"
    
    local build_args=(
        --build-arg NUM="$version"
        --build-arg DISTRIBUTION="$distribution"
        --build-arg PLATFORM="$package_platform"
        --platform "$platform"
        -t "$image_name"
    )
    
    [[ "$action" == "push" ]] && build_args+=(--push) || build_args+=(--load)
    
    docker buildx build "${build_args[@]}" .
}

build_single() {
    local version="$1" repository="$2" distribution="${3:-trixie-slim}" platform="${4:-linux/amd64}" package_platform="${5:-amd64}" tag="${6:-latest}" action="${7:-load}"
    build_image "$version" "$repository" "$distribution" "$platform" "$package_platform" "$tag" "$action"
}

build_matrix() {
    local version="$1" repository="$2" action="${3:-load}"
    local distributions=(bullseye-slim trixie-slim)

    for distribution in "${distributions[@]}"; do
        local dist_suffix=""
        [[ "$distribution" == "bullseye-slim" ]] && dist_suffix="-bullseye"
        [[ "$distribution" == "trixie-slim" ]] && dist_suffix="-trixie"

        # ARM64, ARMv7, AMD64 platforms
        build_image "$version" "$repository" "$distribution" "linux/arm64" "armhf" "${version}-arm64${dist_suffix}" "$action"
        build_image "$version" "$repository" "$distribution" "linux/arm64" "armhf" "latest-arm64${dist_suffix}" "$action"
        build_image "$version" "$repository" "$distribution" "linux/arm/v7" "armhf" "${version}-armhf${dist_suffix}" "$action"
        build_image "$version" "$repository" "$distribution" "linux/arm/v7" "armhf" "latest-armhf${dist_suffix}" "$action"
        build_image "$version" "$repository" "$distribution" "linux/amd64" "amd64" "${version}${dist_suffix}" "$action"
        build_image "$version" "$repository" "$distribution" "linux/amd64" "amd64" "latest${dist_suffix}" "$action"
    done
}

main() {
    [[ $# -lt 2 ]] && usage

    local version="$1" repository="$2" distribution="${3:-trixie-slim}" platform="${4:-linux/amd64}" package_platform="${5:-amd64}" tag="${6:-latest}" action="${7:-push}"

    if [[ "$distribution" == "matrix" ]]; then
        build_matrix "$version" "$repository" "$action"
    else
        build_single "$version" "$repository" "$distribution" "$platform" "$package_platform" "$tag" "$action"
    fi

    [[ "$action" == "load" ]] && docker system prune -a -f --volumes
}

main "$@"
