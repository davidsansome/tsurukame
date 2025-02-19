# Firebase Hosting

This directory gets pushed to Firebase hosting on <https://tsurukame.app>.

[Firebase console](https://console.firebase.google.com/project/tsurukame-wk/hosting/sites/tsurukame-wk).

It hosts:

- The .well-known/apple-app-site-association file, which defines universal
    links.
- Custom fonts which can be downloaded in Tsurukame.

Push to Firebase hosting with:

    firebase deploy --only hosting
