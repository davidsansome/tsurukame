#!/bin/bash

DEVELOPMENT_TEAM=$1
PRODUCT_ID_USER=$2

if [[ "xreset" == "x${DEVELOPMENT_TEAM}" ]];then
  # Reset to original values, useful for pull requests
  DEVELOPMENT_TEAM=7B2GP77Y4A
  PRODUCT_ID_USER=davidsansome
fi

# TODO: Verify args not blank
if [[ "x" == "x${DEVELOPMENT_TEAM}" ]] || [[ "y" == "y${PRODUCT_ID_USER}" ]];then
  echo "ERROR: Missing required argument:"
  echo "  $0 [DEVELOPMENT_TEAM_ID] [PRODUCT_ID_USER]"
  echo "    - OR -"
  echo "  $0 reset"
  echo ""
  echo " Example: $0 7B2GP77Y4A davidsansome"
  echo ""
  exit 1
fi


MAIN_PROJ=./ios/Tsurukame.xcodeproj/project.pbxproj
BKP_PROJ=/tmp/Tsurukame.pbxproj.bkp
TEMP_PROJ=/tmp/Tsurukame.pbxproj.tmp

cp ${MAIN_PROJ} ${BKP_PROJ}

# Step 1: Change the DEVELOPMENT_TEAM
cat ${MAIN_PROJ} | sed 's|DEVELOPMENT_TEAM = .*;|DEVELOPMENT_TEAM = '"${DEVELOPMENT_TEAM}"';|g' > ${TEMP_PROJ}.1

# Step 2: Change PRODUCT_BUNDLE_IDENTIFIER
cat ${TEMP_PROJ}.1 | sed 's|PRODUCT_BUNDLE_IDENTIFIER = com.[^.]*.|PRODUCT_BUNDLE_IDENTIFIER = com.'"${PRODUCT_ID_USER}"'.|g' > ${TEMP_PROJ}.2

# Copy back into place
cp ${TEMP_PROJ}.2 ${MAIN_PROJ}

WATCH_PLIST="./ios/Tsurukame Complication/Info.plist"
WATCH_EXT_PLIST="./ios/Tsurukame Complication Extension/Info.plist"
WATCH_TEMP="/tmp/watch.plist"

# Step 3: Watch complication Info.plist
cat "${WATCH_PLIST}" | sed 's|com.[^.]*.wanikani|com.'"${PRODUCT_ID_USER}"'.wanikani|g' > $WATCH_TEMP
cp $WATCH_TEMP "${WATCH_PLIST}"

# Step 4: Watch complication extension Info.plist
cat "${WATCH_EXT_PLIST}" | sed 's|com.[^.]*.wanikani|com.'"${PRODUCT_ID_USER}"'.wanikani|g' > $WATCH_TEMP
cp $WATCH_TEMP "${WATCH_EXT_PLIST}"

# Cleanup
rm ${TEMP_PROJ}.*
rm ${WATCH_TEMP}