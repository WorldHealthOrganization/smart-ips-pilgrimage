#!/usr/bin/env bash
# site.build siteStep: write the viewer pages (graph explorer, traceability
# matrix, requirements, API, models, node kinds, Kotlin skeleton) into
# <built site>/viewers/, after Jekyll, so they are served verbatim.
set -euo pipefail
site="${1:?usage: site_viewers.sh <built site>}"
SITE_GIT_REF="${SITE_REF:-${SITE_GIT_REF:-}}" bash "$(dirname "$0")/build_site.sh" "$site/viewers"
