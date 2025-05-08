#!/usr/bin/env bash

# Determine whether a folder argument is provided
if [[ $# -eq 4 ]]; then
    FOLDER="$1"
    ARTIFACT_ID="$2"
    OLD_VERSION="$3"
    NEW_VERSION="$4"
elif [[ $# -eq 3 ]]; then
    FOLDER="."
    ARTIFACT_ID="$1"
    OLD_VERSION="$2"
    NEW_VERSION="$3"
else
    echo "Usage: $0 [folder] <artifact_id> <old_version> <new_version>"
    exit 1
fi

# validate input
if [[ -z "${FOLDER}" || -z "${ARTIFACT_ID}" || -z "${OLD_VERSION}" || -z "${NEW_VERSION}" ]]; then
    echo "Usage: $0 <folder> <artifact_id> <old_version> <new_version>"
    exit 1
fi

# check that ${FOLDER} is a directory
if [[ ! -d "${FOLDER}" ]]; then
    echo "Error: ${FOLDER} is not a directory"
    exit 1
fi

# start executing commands inside ${FOLDER}
pushd "${FOLDER}" > /dev/null
ARTIFACTS=$(ls -a | grep ${ARTIFACT_ID}-${NEW_VERSION})
if [[ -z "${ARTIFACTS}" ]]; then
    echo "Error: No ${ARTIFACT_ID}-${NEW_VERSION} files found in ${FOLDER}"
    exit 1
else
    mkdir -p apache-dist
    for ARTIFACT in ${ARTIFACTS}; do
        cp ${ARTIFACT} apache-dist/
    done
    pushd apache-dist > /dev/null
    echo "Importing ${ARTIFACT_ID}-${NEW_VERSION} to Apache dist"
    svn import -m "Release ${ARTIFACT_ID}-${NEW_VERSION}" . https://dist.apache.org/repos/dist/release/sling
    echo "Preparing to remove previous version ${ARTIFACT_ID}-${OLD_VERSION}"
    OLD_ARTIFACTS=$(svn ls https://dist.apache.org/repos/dist/release/sling/ | grep "${ARTIFACT_ID}-${OLD_VERSION}" | while read line; do echo "https://dist.apache.org/repos/dist/release/sling/$line"; done)
    if [[ -z "${OLD_ARTIFACTS}" ]]; then
        echo "Error: No ${ARTIFACT_ID}-${OLD_VERSION} files found in Apache dist"
        exit 1
    else
        svn delete -m "Remove old version ${ARTIFACT_ID}-${OLD_VERSION}" ${OLD_ARTIFACTS}
    fi
    popd > /dev/null
fi
popd > /dev/null
echo "Done! Visit https://dist.apache.org/repos/dist/release/sling/ to validate."
