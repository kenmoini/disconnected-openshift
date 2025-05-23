#!/bin/bash

# Mirror registries must support pushing without a tag (only a shasum)

# Download oc binary
# https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/

# Make a joined container pull secret containing all RH credentials as well as your own
# ./join-auths.sh private-ps.json red-hat-ps.json > ~/.combined-mirror-ps.json

# Path to the pull secret
AUTH_FILE=${AUTH_FILE:="/root/.combined-mirror-ps.json"}

# What OpenShift release to mirror
OCP_RELEASE=${OCP_RELEASE:="4.17.16"}

# Operational flags
DRY_RUN=${DRY_RUN:="true"}
EXTRA_OC_ARGS=${EXTRA_OC_ARGS:=""}
MIRROR_METHOD=${MIRROR_METHOD:="direct"} # direct or file
MIRROR_DIRECTION=${MIRROR_DIRECTION:="download"} # download or upload, only used when MIRROR_METHOD=file

# If this is a direct mirror, set the registry and path
LOCAL_REGISTRY=${LOCAL_REGISTRY:="disconn-harbor.d70.kemo.labs"}
LOCAL_REGISTRY_BASE_PATH=${LOCAL_REGISTRY_BASE_PATH:="openshift"}
LOCAL_REGISTRY_IMAGES_PATH="${LOCAL_REGISTRY}/${LOCAL_REGISTRY_BASE_PATH}"
LOCAL_REGISTRY_RELEASE_PATH=${LOCAL_REGISTRY_RELEASE_PATH:="${LOCAL_REGISTRY_IMAGES_PATH}-release"}

# No need to change these things - probably
ARCHITECTURE=${ARCHITECTURE:="x86_64"} # x86_64, aarch64, s390x, ppc64le
SKIP_TLS_VERIFY=${SKIP_TLS_VERIFY:="false"}
OCP_MAJOR_RELEASE="$(echo $OCP_RELEASE | cut -d. -f1).$(echo $OCP_RELEASE | cut -d. -f2)"
TARGET_SAVE_PATH=${TARGET_SAVE_PATH:="/tmp/ocp-mirror-${OCP_RELEASE}"} # Only used if MIRROR_METHOD=file
PRODUCT_REPO="openshift-release-dev"
RELEASE_NAME="ocp-release"
UPSTREAM_REGISTRY=${UPSTREAM_REGISTRY:="quay.io"}
UPSTREAM_PATH="${PRODUCT_REPO}/${RELEASE_NAME}"

# Check for needed binaries
if [ ! $(which oc) ]; then echo "oc not found!" && exit 1; fi

# Make the save path directory
mkdir -p ${TARGET_SAVE_PATH}

# Mirror OpenShift release
echo "> Mirroring OpenShift Release..."
echo "> Auth file path: ${AUTH_FILE}"
echo "> Release Version: ${OCP_RELEASE}"
echo "> Architecture: ${ARCHITECTURE}"
echo "> Mirror Method: ${MIRROR_METHOD}"
if [ "${MIRROR_METHOD}" == "direct" ]; then echo "> Local Registry: ${LOCAL_REGISTRY}"; fi
if [ "${MIRROR_METHOD}" == "file" ]; then echo "> Save Path: ${TARGET_SAVE_PATH}" && echo "> Mirror Direction: ${MIRROR_DIRECTION}"; fi
echo "> Dry Run: ${DRY_RUN}"

MIRROR_CMD="oc adm release mirror ${EXTRA_OC_ARGS} -a ${AUTH_FILE} --from=${UPSTREAM_REGISTRY}/${UPSTREAM_PATH}:${OCP_RELEASE}-${ARCHITECTURE}"
if [ "${MIRROR_METHOD}" == "direct" ]; then MIRROR_CMD="${MIRROR_CMD} --to=${LOCAL_REGISTRY_IMAGES_PATH} --to-release-image=${LOCAL_REGISTRY_RELEASE_PATH}:${OCP_RELEASE}-${ARCHITECTURE}"; fi
if [ "${MIRROR_METHOD}" == "file" ]; then
  if [ "${MIRROR_DIRECTION}" == "download" ]; then MIRROR_CMD="${MIRROR_CMD} --to-dir=${TARGET_SAVE_PATH}"; fi
  if [ "${MIRROR_DIRECTION}" == "upload" ]; then
    MIRROR_CMD="oc image mirror ${EXTRA_OC_ARGS} -a ${AUTH_FILE} --skip-missing --from-dir=${TARGET_SAVE_PATH}"
    MIRROR_CMD="${MIRROR_CMD} \"file://openshift/release:${OCP_RELEASE}*\" ${LOCAL_REGISTRY}/${LOCAL_REGISTRY_BASE_PATH}"
  fi
fi
if [ "${DRY_RUN}" == "true" ]; then MIRROR_CMD="${MIRROR_CMD} --dry-run"; fi

echo "> Running: ${MIRROR_CMD}"
$MIRROR_CMD
