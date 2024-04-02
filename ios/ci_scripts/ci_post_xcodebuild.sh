#!/bin/sh

# Make TestFlight release notes from the most recent 3 commits.
if [[ -d "$CI_APP_STORE_SIGNED_APP_PATH" ]]; then
  TESTFLIGHT_DIR_PATH=../TestFlight
  mkdir $TESTFLIGHT_DIR_PATH
  git fetch --deepen 3 && git log -3 --pretty=format:"- %s" >! $TESTFLIGHT_DIR_PATH/WhatToTest.en-AU.txt
fi
