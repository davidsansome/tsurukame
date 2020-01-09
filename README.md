[![CircleCI](https://circleci.com/gh/davidsansome/tsurukame.svg?style=shield)](https://circleci.com/gh/davidsansome/tsurukame)

Tsurukame is an unofficial WaniKani app for iOS.  It helps you learn Japanese Kanji.

You can download Tsurukame on the App Store.

[![Download on the App Store](https://devimages-cdn.apple.com/app-store/marketing/guidelines/images/badge-example-preferred.png)](https://itunes.apple.com/us/app/tsurukame-for-wanikani/id1367114761)

# Building Tsurukame

If you want to build the iOS app yourself, there are three main things you will need to do.
1. Install the CocoaPods dependencies
2. Change the signing identifiers
3. Create the data.bin

## Install the CocoaPods dependencies
First, you will need to install [CocoaPods](https://cocoapods.org) if you don't already have it. The website suggests using `sudo gem install cocoapods`.

Next, you will need to switch the current directory to the `ios` directory. You can do this using:

	cd /path/to/tsurukame/ios

Of course, replace `/path/to` with the actual path to the Tsurukame directory.
Finally, simply install the dependencies using `pod install`.

## Change the signing identifiers
You'll have to change the app bundle identifiers in the main target and app extension to match your Apple Developer Account.

1. You will need a registered Apple Developer Account. If you don't have one, you can get one for free at [Apple Developer](https://developer.apple.com/account/).
2. If you already know your `DEVELOPMENT_TEAM` and bundle identifiers, skip this step.
	1. Otherwise, you will need to open Xcode, and open `ios/Tsurukame.xcworkspace`, which is what you will use to build the app.
	2. You will need to go click on the Tsurukame project in the left sidebar.
	3. In the General and Signing & Capabilities tabs, change the bundle identifier & development team as shown in the screenshots below.
    
    <img width="300" alt="General" src="https://user-images.githubusercontent.com/46784000/72098368-ed64e980-32e3-11ea-8cee-e1837d993269.PNG"><img width="300" alt="Signing & Capabilities" src="https://user-images.githubusercontent.com/46784000/72098370-ed64e980-32e3-11ea-83a9-1783a94213d5.PNG">
3. Open `project.pbxproj` which can be found in the contents of `ios/Tsurukame.xcodeproj` in an external editor (not Xcode), and find and replace:
	1. `7B2GP77Y4A;` with your development team followed by a semicolon
	2. `com.davidsansome.` with the beginning of your bundle identifier.
Alternately, you can attempt to do step 3 manually within Xcode by searching for these things.

## Create data.bin

### Using the tools

All the data - kanji, meanings, readings, mnemonics, etc. - are stored in a data.bin file that gets bundled inside the iOS app.  You can manipulate this file (and create it from scratch) using the Go tools in this repository.

Before doing anything else, follow the [Go Getting Started](https://golang.org/doc/install) guide to install Go and set up your environment.  Then you can check out the Tsurukame code inside your gopath:

    go get -u -v github.com/davidsansome/tsurukame/...

### Create a new data.bin

You'll need:

1. Your WaniKani APIv2 key.  Get it from https://www.wanikani.com/settings/account.
2. Your HTTP cookie from your web browser.  WaniKani doesn't expose everything we need in its API - specifically the mnemonics, explanations and example sentences - so we need to scrape the JSON API as well.

    1. Open the Developer Tools in Chrome (F12).
    2. Navigate to https://www.wanikani.com.
    3. Click the Network tab in developer tools and click the top request.
    4. Scroll down to the "Request Headers" section in the Headers tab.
    5. In the Cookie line, look for `_wanikani_session=` and copy the 32-character hex string.

Make sure the current directory is the `tsurukame` directory. If not, use `cd` to change it.

Run the scraper:

    mkdir data
    go run cmd/scrape/main.go --api-token [Your API token] --cookie [Your HTTP cookie]

This will take a few minutes to download everything.  It stores its output in the `data` directory (change this with `--out`).  You can stop it and start it again and it will pick up from where it left off.

You can inspect the files in `data` using the dump tool below - just change the argument from `data.bin` to `data`.

Combine the individual files in `data` into a `data.bin` using the combine tool:

    go run cmd/combine/main.go --in data --out data.bin

Now the data.bin is ready for use! You should be able to build Tsurukame now!

## Inspect data.bin
If you want to inspect the data.bin, here are some things you can do.

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
