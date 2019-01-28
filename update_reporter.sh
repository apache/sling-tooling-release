#!/bin/bash

function display_usage() {
    echo "$0 <path_to_file_containing_release_names>"
}

source update_reporter.config
if [[ -z "${APACHE_USER}" ]]; then
    echo "Please set the APACHE_USER variable in the update_reporter.config file."
    exit 1
fi
if [[ -z "${APACHE_PASSWORD}" ]]; then
    echo "Please set the APACHE_PASSWORD variable in the update_reporter.config file."
    exit 1
fi
if [[ -z "$1" ]]; then
    echo "Please provide a file with the release names, one release name per line."
    display_usage
    exit 1
fi
BASIC="$(echo -n "$APACHE_USER:$APACHE_PASSWORD" | base64)"
DATE="`date '+%Y-%m-%d'`"
EPOCH="`date '+%s'`"
while IFS='' read -r line || [[ -n "$line" ]]; do
    release=${line// /+}
    status=`curl -s -o /dev/null -w "%{http_code}" 'https://reporter.apache.org/addrelease.py' \
            -H 'Connection: keep-alive' \
            -H 'Cache-Control: max-age=0' \
            -H "Authorization: Basic ${BASIC}" \
            -H 'Origin: https://reporter.apache.org' \
            -H 'Upgrade-Insecure-Requests: 1' \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.20 Safari/537.36' \
            -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' \
            -H 'Referer: https://reporter.apache.org/addrelease.html?sling' \
            -H 'Accept-Encoding: gzip, deflate, br' \
            --data "date=${EPOCH}&committee=sling&version=${release}&xdate=${DATE}" --compressed`
    if [[ "$status" -ne 200 ]]; then
        echo "Failed to update ${line}: got status code ${status}"
        exit 1
    fi
done < "$1"



