#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <version> <repository> [distribution] [docker_platform] [package_platform] [tag]"
    echo "Defaults: distribution=trixie-slim, docker_platform=linux/amd64, package_platform=amd64, tag=latest"
    echo "Use 'matrix' as distribution to run the full build matrix"
    exit 1
}

build_and_push() {
    local version="$1"
    local repository="$2"
    local distribution="$3"
    local docker_platform="$4"
    local package_platform="$5"
    local tag="$6"

    echo "### [Building ${tag} (${distribution} on ${docker_platform})] ###"
    docker buildx build \
        --build-arg NUM="$version" \
        --build-arg DISTRIBUTION="$distribution" \
        --build-arg PLATFORM="$package_platform" \
        --platform "$docker_platform" \
        -t "${repository}/expressvpn:${tag}" \
        --load .
}

build_single() {
    local version="$1"
    local repository="$2"
    local distribution="${3:-trixie-slim}"
    local docker_platform="${4:-linux/amd64}"
    local package_platform="${5:-amd64}"
    local tag="${6:-latest}"

    build_and_push "$version" "$repository" "$distribution" "$docker_platform" "$package_platform" "$tag"
}

build_matrix() {
    local version="$1"
    local repository="$2"

    local distributions=(bullseye-slim trixie-slim)

    for distribution in "${distributions[@]}"; do
        local dist_suffix=""
        if [[ "$distribution" == "bullseye-slim" ]]; then
            dist_suffix="-bullseye"
        elif [[ "$distribution" == "trixie-slim" ]]; then
            dist_suffix="-trixie"
        fi

        # arm64 targets expressvpn armhf packages
        local arm64_suffix="-arm64${dist_suffix}"
        build_and_push "$version" "$repository" "$distribution" "linux/arm64" "armhf" "${version}${arm64_suffix}"
        build_and_push "$version" "$repository" "$distribution" "linux/arm64" "armhf" "latest${arm64_suffix}"

        # armhf targets
        local armhf_suffix="-armhf${dist_suffix}"
        build_and_push "$version" "$repository" "$distribution" "linux/arm/v7" "armhf" "${version}${armhf_suffix}"
        build_and_push "$version" "$repository" "$distribution" "linux/arm/v7" "armhf" "latest${armhf_suffix}"

        # amd64 targets expressvpn amd64 packages
        local amd64_suffix="${dist_suffix}"
        build_and_push "$version" "$repository" "$distribution" "linux/amd64" "amd64" "${version}${amd64_suffix}"
        build_and_push "$version" "$repository" "$distribution" "linux/amd64" "amd64" "latest${amd64_suffix}"
    done
}

main() {
    if [[ $# -lt 2 ]]; then
        usage
    fi

    local version="$1"
    local repository="$2"
    local distribution="${3:-trixie-slim}"
    local docker_platform="${4:-linux/amd64}"
    local package_platform="${5:-amd64}"
    local tag="${6:-latest}"

    # If distribution is "matrix", run the full build matrix
    if [[ "$distribution" == "matrix" ]]; then
        build_matrix "$version" "$repository"
    else
        # Otherwise, build a single image with the specified or default parameters
        build_single "$version" "$repository" "$distribution" "$docker_platform" "$package_platform" "$tag"
    fi

    echo "### [Build completed successfully] ###"
    # docker system prune -a -f --volumes
}

main "$@"
