The content displayed in Tsurukame comes from WaniKani, and its use is covered by
https://www.wanikani.com/terms, NOT the terms of the Tsurukame software license.

[![CircleCI](https://circleci.com/gh/davidsansome/tsurukame.svg?style=shield)](https://circleci.com/gh/davidsansome/tsurukame)

Tsurukame is an unofficial WaniKani app for iOS.  It helps you learn Japanese Kanji.

You can download the latest stable release of Tsurukame on the App Store.

[![Download on the App Store](https://devimages-cdn.apple.com/app-store/marketing/guidelines/images/badge-example-preferred.png)](https://itunes.apple.com/us/app/tsurukame-for-wanikani/id1367114761)

Or join the [TestFlight beta](https://testflight.apple.com/join/Fijye2AA)
which is updated automatically any time there's a commit to this Git repository.

# Building Tsurukame

If you want to build the iOS app yourself, you will need to change the signing identifiers.

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

# Update the CocoaPods dependencies
First, you will need to install [CocoaPods](https://cocoapods.org) if you don't already have it. The website suggests using `sudo gem install cocoapods`.

Next, you will need to switch the current directory to the `ios` directory using `cd`. 
Finally, simply install the dependencies using `pod install` or `pod update`.
