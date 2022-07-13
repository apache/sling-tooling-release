#!/bin/bash -eu

if [ $# -ne 1 ]; then
    echo "Usage: $0 sling_dist_dir"
    exit 1
fi

sling_dist_dir="${1}"

if [ ! -d "${sling_dist_dir}" ]; then
    echo "${sling_dist_dir} is not a directory"
    exit 1
fi

for release_file in $(find "${sling_dist_dir}" -name '*-source-release.zip'); do
    checksum_file="${release_file}.sha512"
    if [ ! -f "${checksum_file}" ] ; then
        echo "Missing SHA512 checksum for ${release_file}, creating"
        sha512sum "${release_file}" > "${checksum_file}"
    fi
done
