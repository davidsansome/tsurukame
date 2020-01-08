[![CircleCI](https://circleci.com/gh/davidsansome/tsurukame.svg?style=shield)](https://circleci.com/gh/davidsansome/tsurukame)

Tsurukame is an unofficial WaniKani app for iOS.  It helps you learn Japanese
Kanji.

You can download Tsurukame on the App Store.

[![Download on the App Store](https://devimages-cdn.apple.com/app-store/marketing/guidelines/images/badge-example-preferred.png)](https://itunes.apple.com/us/app/tsurukame-for-wanikani/id1367114761)

## Building Tsurukame

If you want to build the iOS app yourself then you first need to create the data file that gets bundled inside the iOS app.

## Using the tools

All the data - kanji, meanings, readings, mnemonics, etc. - are stored in a data.bin file that gets bundled inside the iOS app.  You can manipulate this file (and create it from scratch) using the Go tools in this repository.

Before doing anything else, follow the [Go Getting Started](https://golang.org/doc/install) guide to install Go and set up your environment.  Then you can check out the Tsurukame code inside your gopath:

    go get -u -v github.com/davidsansome/tsurukame/...

### Create a new data.bin

You'll need:

1. Your WaniKani V2 API key.  Get it from https://www.wanikani.com/settings/account.
2. Your HTTP cookie from your web browser.  WaniKani doesn't expose everything we need in its API - specifically the mnemonics, explanations and example sentences - so we need to scrape the JSON API as well.

    1. Open the Developer Tools in Chrome (F12).
    2. Navigate to https://www.wanikani.com.
    3. Click the Network tab in developer tools and click the top request.
    4. Scroll down to the "Request Headers" section in the Headers tab.
    5. In the Cookie line, look for _wanikani_session= and copy the 32-character hex string.

Run the scraper:

    mkdir data
    go run cmd/scrape/main.go --api-token [Your API token] --cookie [Your HTTP cookie]

This will take a few minutes to download everything.  It stores its output in the ```data``` directory (change this with ```--out```).  You can stop it and start it again and it will pick up from where it left off.

You can inspect the files in ```data``` using the dump tool below - just change the argument from ```data.bin``` to ```data```.

Combine the individual files in ```data``` into a ```data.bin``` using the combine tool:

    go run cmd/combine/main.go --in data --out data.bin

### Inspect data.bin

List all the subjects in a data.bin:

```
$ go run cmd/dump/main.go data.bin

1. ground
2. fins
3. drop
4. seven
5. slide
6. barb
...
```

Dump one subject by ID:

```
$ go run cmd/dump/main.go data.bin 6

id: 6
level: 1
slug: "barb"
japanese: "\344\272\205"
meanings: <
  meaning: "Barb"
  is_primary: true
>
amalgamation_subject_ids: 465
amalgamation_subject_ids: 775
amalgamation_subject_ids: 2430
radical: <
  formatted_mnemonic: <
    text: "This radical is shaped like a "
  >
  formatted_mnemonic: <
    format: RADICAL
    text: "barb"
  >
  formatted_mnemonic: <
    text: ", like you'd see on barb wire, or something. Imagine one of these getting stuck in your arm, and think about how much it would hurt to pull it out with that hook on the end. Say out loud \"Oh dang... I got this barb stuck in me.\""
  >
>
```

This is a text protobuf, described by [wanikani.proto](https://github.com/davidsansome/tsurukame/blob/master/proto/wanikani.proto).
