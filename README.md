The content displayed in Tsurukame comes from WaniKani, and its use is covered by
https://www.wanikani.com/terms, NOT the terms of the Tsurukame software license.

[![CircleCI](https://circleci.com/gh/davidsansome/tsurukame.svg?style=shield)](https://circleci.com/gh/davidsansome/tsurukame)

Tsurukame is an unofficial WaniKani app for iOS.  It helps you learn Japanese Kanji.

You can download the latest stable release of Tsurukame on the App Store.

[![Download on the App Store](https://devimages-cdn.apple.com/app-store/marketing/guidelines/images/badge-example-preferred.png)](https://itunes.apple.com/us/app/tsurukame-for-wanikani/id1367114761)

Or join the [TestFlight beta](https://testflight.apple.com/join/Fijye2AA)
which is updated automatically any time there's a commit to this Git repository.

# Building Tsurukame

If you want to build the iOS app yourself, you will need to change the signing identifiers and create `data.bin`.

## Change the signing identifiers
You'll have to change the app bundle identifiers in the main target and app extension to match your Apple Developer Account.

1. You will need a registered Apple Developer Account. If you don't have one, you can get one for free at [Apple Developer](https://developer.apple.com/account/).
2. Next, you will need to open Xcode, and open `ios/Tsurukame.xcworkspace`, which is what you will use to build the app.
	1. You will need to click on the Tsurukame project in the left sidebar.
	2. For each target, in its Signing & Capabilities tab, turn on the automatically manage signing checkbox, as shown in the first arrow in the screenshot below:

    <img width="300" alt="Signing & Capabilities" src="https://user-images.githubusercontent.com/46784000/86614807-2a4f2780-bf79-11ea-8de5-dd3434b48afd.png">
3. If you already know your development team identifier, skip to step 4.
	1. Change the development team and bundle identifier as shown in the second and third arrows in the screenshot.
	2. You should see the development team identifier appear, as shown at the bottom of the screenshot. 
4. Open Terminal, and ensure the current directory is in the `tsurukame` directory, or use `cd` to change it if not. Then type the following command, replacing `7B2GP77Y4A` with your development team, such as `D526893WQ3`, and `com.davidsansome.wanikani` with your identifier, such as `com.mzsanford.wanikani`:
    `utils/set-team-product.sh 7B2GP77Y4A com.davidsansome.wanikani` 

## Create data.bin

### Using the tools

All the data - kanji, meanings, readings, mnemonics, etc. - are stored in a data.bin file that gets bundled inside the iOS app.  You can manipulate this file (and create it from scratch) using the Go tools in this repository.

Before doing anything else, follow the [Go Getting Started](https://golang.org/doc/install) guide to install Go and set up your environment.  Then you can check out the Tsurukame code inside your gopath:

    go get -u -v github.com/davidsansome/tsurukame/...

### Create a new data.bin

You'll need a WaniKani APIv2 key.  Get it from https://www.wanikani.com/settings/account.

Open Terminal and make sure the current directory is the `tsurukame` directory. If not, use `cd` to change it.
Run the scraper, replacing `[Your API token]` with your APIv2 key:

    mkdir data
    go run cmd/scrape/main.go --api-token [Your API token]

This will take a few minutes to download everything.  It stores its output in the `data` directory (change this with `--out`).  You can stop it and start it again and it will pick up from where it left off.

You can inspect the files in `data` using the dump tool below - just change the argument from `data.bin` to `data`.

Combine the individual files in `data` into a `data.bin` using the combine tool:

    go run cmd/combine/main.go --in data --out data.bin

Now the data.bin is ready for use! You should be able to build Tsurukame now!

# Inspect data.bin
If you want to inspect the data.bin, here are some things you can do.

List all the subjects in a data.bin:

    go run cmd/dump/main.go data.bin

```
1. ground
2. fins
3. drop
4. seven
5. slide
6. barb
...
```

Dump one subject by ID:

    go run cmd/dump/main.go data.bin 6

```
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

# Update the CocoaPods dependencies
First, you will need to install [CocoaPods](https://cocoapods.org) if you don't already have it. The website suggests using `sudo gem install cocoapods`.

Next, you will need to switch the current directory to the `ios` directory using `cd`. 
Finally, simply install the dependencies using `pod install` or `pod update`.
