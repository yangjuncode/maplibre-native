#!/usr/bin/env bash

set -e
set -o pipefail
set -u

# dynamic environment variables:
#     VERSION_TAG={determined automatically}: Version tag in format macos-vX.X.X-pre.X
#     GITHUB_RELEASE=true: Upload to github
#     BINARY_DIRECTORY=build/macos/deploy: Directory in which to save test packages

# environment variables and dependencies:
#     - You must run "mbx auth ..." before running
#     - Set GITHUB_TOKEN to a GitHub API access token in your environment to use GITHUB_RELEASE
#     - "wget" is required for downloading the zip files from s3
#     - The "github-release" command is required to use GITHUB_RELEASE

function step { >&2 echo -e "\033[1m\033[36m* $@\033[0m"; }
function finish { >&2 echo -en "\033[0m"; }
trap finish EXIT

ENABLE_APP_PUBLISH=${ENABLE_APP_PUBLISH:-NO}

publish() {
    OPTRESET=1
    OPTIND=
    local arg
    local rule=
    local suffix=
    local app=
    while getopts 'r:s:a:' arg; do
        case ${arg} in
            r) rule=${OPTARG};;
            s) suffix=${OPTARG};;
            a) app=${OPTARG};;
            *) "Usage: [-r rule] [-s suffix] [-a app]"; return
        esac
    done
    
    step "Building: make ${rule} ${suffix}"
    make ${rule}
    step "Publishing ${rule} with ${suffix}"
    local file_name=""
    if [ -z ${suffix} ]
    then
        file_name=mapbox-macos-sdk-${PUBLISH_VERSION}.zip
    else
        file_name=mapbox-macos-sdk-${PUBLISH_VERSION}-${suffix}.zip
    fi
    step "Compressing ${file_name}…"
    cd build/macos/pkg
    rm -f ../deploy/${file_name}
    zip -yr ../deploy/${file_name} *
    cd -
    if [[ "${GITHUB_RELEASE}" == true ]]; then
        echo "Uploading ${file_name} to GitHub"
        github-release upload \
            --tag "macos-v${PUBLISH_VERSION}" \
            --name ${file_name} \
            --file "${BINARY_DIRECTORY}/${file_name}" > /dev/null
    fi
    if [ ${app} ]; then
        file_name="Mapbox GL.app.zip"
        step "Compressing ${file_name}…"
        cd build/macos/app
        rm -f "${file_name}"
        zip -yr "../deploy/${file_name}" 'Mapbox GL.app'
        cd -
        if [[ "${GITHUB_RELEASE}" == true ]]; then
            echo "Uploading ${file_name} to GitHub"
            github-release upload \
                --tag "macos-v${PUBLISH_VERSION}" \
                --name "${file_name}" \
                --file "${BINARY_DIRECTORY}/${file_name}" > /dev/null
        fi
    fi
}

export GITHUB_USER=maptiler
export GITHUB_REPO=maplibre-gl-native
export BUILDTYPE=Release

VERSION_TAG=${VERSION_TAG:-''}
PUBLISH_VERSION=
BINARY_DIRECTORY=${BINARY_DIRECTORY:-build/macos/deploy}
GITHUB_RELEASE=${GITHUB_RELEASE:-true}
PUBLISH_PRE_FLAG=''

if [[ ${GITHUB_RELEASE} = "true" ]]; then
    GITHUB_RELEASE=true # Assign bool, not just a string

    if [[ -z `which github-release` ]]; then
        step "Installing github-release…"
        brew install github-release
        if [ -z `which github-release` ]; then
            echo "Unable to install github-release. See: https://github.com/aktau/github-release"
            exit 1
        fi
    fi
fi

if [[ -z ${VERSION_TAG} ]]; then
    step "Determining version number from most recent relevant git tag…"
    VERSION_TAG=$( git describe --tags --match=macos-v*.*.* --abbrev=0 )
    echo "Found tag: ${VERSION_TAG}"
fi

if [[ $( echo ${VERSION_TAG} | grep --invert-match macos-v ) ]]; then
    echo "Error: ${VERSION_TAG} is not a valid macOS version tag"
    echo "VERSION_TAG should be in format: macos-vX.X.X-pre.X"
    exit 1
fi

if [[ $( wget --spider -O- https://api.github.com/repos/${GITHUB_USER}/${GITHUB_REPO}/releases/tags/${VERSION_TAG} 2>&1 | grep -c "404 Not Found" ) == 0 ]]; then
    echo "Error: ${VERSION_TAG} has already been published on GitHub"
    echo "See: https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/tag/${VERSION_TAG}"
    exit 1
fi

PUBLISH_VERSION=$( echo ${VERSION_TAG} | sed 's/^macos-v//' )
git checkout ${VERSION_TAG}

step "Deploying version ${PUBLISH_VERSION}…"

if [[ ${#} -eq 3 &&  $3 == "-g" ]]; then
    GITHUB_RELEASE=true
fi

npm install --ignore-scripts
mkdir -p ${BINARY_DIRECTORY}

if [[ "${GITHUB_RELEASE}" == true ]]; then
    step "Create GitHub release…"
    if [[ $( echo ${PUBLISH_VERSION} | awk '/[0-9]-/' ) ]]; then
        PUBLISH_PRE_FLAG='--pre-release'
    fi
    github-release release \
        --tag "macos-v${PUBLISH_VERSION}" \
        --name "macos-v${PUBLISH_VERSION}" \
        --draft ${PUBLISH_PRE_FLAG}
fi

step "publish -r xpackage -s symbols"
publish -r xpackage -s symbols

if [[ ${ENABLE_APP_PUBLISH} = "YES" ]]; then
    step "publish -r "xpackage SYMBOLS=NO" -a true"
    publish -r "xpackage SYMBOLS=NO" -a true
else
    step "publish -r "xpackage SYMBOLS=NO"
    publish -r "xpackage SYMBOLS=NO"
fi;

step "Finished deploying ${PUBLISH_VERSION} in $(($SECONDS / 60)) minutes and $(($SECONDS % 60)) seconds"
