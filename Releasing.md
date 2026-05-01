# Publish to the App Store

## First time setup

1. Install fastlane

    ```
    brew install fastlane
    ```

1. Get an App Store API key

    1. Go to https://appstoreconnect.apple.com/access/integrations/api
    2. Create a new key, give it the "Admin" permission
    3. Download the key .p8 file
    4. Note the "Key ID" from the App Store Connect API page.
    5. Create a file `fastlane/app_store_api_key.json`:

        ```
        jq -n --arg key_id $KEY_ID --arg key "$(cat $KEY_P8_FILENAME)" \
          '{ issuer_id: "69a6de98-2c86-47e3-e053-5b8c7c11a4d1", key_id: $key_id, key: $key }' \
          > fastlane/app_store_api_key.json
        ```

1.  Log into the gcloud CLI so fastlane can manage certificates and provisioning
    profiles.

    ```
    gcloud auth application-default login
    ```

## Renew certificates after they expire

1.  Delete expired certificates: `fastlane match nuke distribution`
2.  Make new certificates: `fastlane match appstore`

## Make release notes

1.  Find the tag of the last released version: `jj tag l`
2.  List the comments between then and now: `jj log -T builtin_log_oneline -r $LAST_TAG..@`
3.  Summarise them into the `fastlane/metadata/en-AU/release_notes.txt` file
4.  Commit them: `jj commit -m "Update release notes for $VERSION"`

## Make a new release

1.  `fastlane release`
2.  Go to https://appstoreconnect.apple.com/apps/1367114761/distribution/ios/version/inflight
    1.  Check "Sign-in required" and enter the test account credentials
    2.  Click "Add for review" and then "Ready for review"
3.  `fastlane tag_release`
4.  `fastlane new_version`