#!/bin/bash

set -e

DEVELOPMENT_TEAM=$1
PRODUCT_ID=$2

if [[ "reset" == "${DEVELOPMENT_TEAM}" ]];then
  # Reset to original values, useful for pull requests
  DEVELOPMENT_TEAM=7B2GP77Y4A
  PRODUCT_ID=com.davidsansome.wanikani
fi

if [[ "" == "${DEVELOPMENT_TEAM}" ]] || [[ "" == "${PRODUCT_ID}" ]];then
  echo "ERROR: Missing required argument:"
  echo "  $0 [DEVELOPMENT_TEAM_ID] [PRODUCT_ID]"
  echo "    - OR -"
  echo "  $0 reset"
  echo ""
  echo " Example: $0 7B2GP77Y4A com.davidsansome.wanikani"
  echo ""
  exit 1
fi


MAIN_PROJ=./ios/Tsurukame.xcodeproj/project.pbxproj
BKP_PROJ=/tmp/Tsurukame.pbxproj.bkp
TEMP_PROJ=/tmp/Tsurukame.pbxproj.tmp

cp "${MAIN_PROJ}" "${BKP_PROJ}"

# Step 1: Change the DEVELOPMENT_TEAM
sed 's|DEVELOPMENT_TEAM = .*;|DEVELOPMENT_TEAM = '"${DEVELOPMENT_TEAM}"';|g' "${MAIN_PROJ}" > "${TEMP_PROJ}.1"

# Step 2: Change PRODUCT_BUNDLE_IDENTIFIER
sed 's|PRODUCT_BUNDLE_IDENTIFIER = com\.[^.]*\.[^.;]*|PRODUCT_BUNDLE_IDENTIFIER = '"${PRODUCT_ID}"'|g' "${TEMP_PROJ}.1" > "${TEMP_PROJ}.2"

# Copy back into place
cp "${TEMP_PROJ}.2" "${MAIN_PROJ}"

WATCH_PLIST="./ios/Complication/Info.plist"
WATCH_EXT_PLIST="./ios/ComplicationExtension/Info.plist"
WATCH_TEMP="/tmp/watch.plist"

# Step 3: Watch complication Info.plist
if [[ -f "${WATCH_PLIST}" ]];then
  sed 's|com\.[^.]*\.[^.<]*|'"${PRODUCT_ID}"'|g' "${WATCH_PLIST}" > "$WATCH_TEMP"
  cp "$WATCH_TEMP" "${WATCH_PLIST}"

  # Step 4: Watch complication extension Info.plist
  cat "${WATCH_EXT_PLIST}" | perl -pne 's/com\.((?!apple)[^.]+)\.[^.]+(.*)</'${PRODUCT_ID}'\2</g' > "$WATCH_TEMP"
  cp "$WATCH_TEMP" "${WATCH_EXT_PLIST}"
fi


# Cleanup
rm ${TEMP_PROJ}.* || true
rm "${WATCH_TEMP}" || true
