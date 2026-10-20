#!/usr/bin/env bash
#
# Copyright (c) 2026 Oracle and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


set -euo pipefail

base_url=${BW_SCRIPT_BASE_URL:-https://raw.githubusercontent.com/barchetta/helidon-infra/main/etc/scripts}
base_url=${base_url%/}
script_name=${BW_SCRIPT_NAME:-$(basename "$0")}
script_url=$base_url/$script_name

cache_root=${XDG_CACHE_HOME:-${HOME:-}/.cache}
if [[ -z $cache_root || $cache_root == /.cache ]]; then
    printf 'Cannot determine a cache directory; set XDG_CACHE_HOME or HOME.\n' >&2
    exit 1
fi

cache_script_name=$(basename "$script_name")
cache_name=${cache_script_name%.*}
if [[ -z $cache_name ]]; then
    cache_name=$cache_script_name
fi
if [[ -z $cache_name || $cache_name == . || $cache_name == .. ]]; then
    printf 'Invalid script name: %s\n' "$script_name" >&2
    exit 1
fi

cache_dir=$cache_root/bash-wrapper/$cache_name
mkdir -p "$cache_dir"

script_hash=$(printf '%s' "$script_url" | shasum -a 256)
cached_script=$cache_dir/${script_hash%% *}.sh
if [[ ! -f $cached_script ]]; then
    downloaded_script=$(mktemp "$cache_dir/.download.XXXXXX")
    trap 'rm -f "$downloaded_script"' EXIT

    if ! curl --fail --location --silent --show-error --connect-timeout 5 --max-time 30 \
            --output "$downloaded_script" -- "$script_url"; then
        printf 'Cannot download %s.\n' "$script_url" >&2
        exit 1
    fi

    chmod 700 "$downloaded_script"
    mv -f "$downloaded_script" "$cached_script"
    rm -f "$downloaded_script"
    trap - EXIT
fi

invoked_script=$(dirname "$0")/$script_name
bash_options=(-c)
IFS= read -r shebang < "$cached_script" || true
if [[ $shebang =~ ^#!.*[[:space:]]-e([[:space:]]|$) ]]; then
    bash_options=(-e -c)
fi
exec bash "${bash_options[@]}" 'gbw_script=$1; shift; source "$gbw_script" "$@"' \
         "$invoked_script" "$cached_script" "$@"
