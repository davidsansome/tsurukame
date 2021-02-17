// Copyright 2021 David Sansome
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import PromiseKit
import Reachability

#if !DEBUG

  // In release mode this class does nothing.
  @objc(TKMScreenshotter)
  @objcMembers
  class Screenshotter: NSObject {
    static let isActive = false
    class func setUp() {}
    static func createLocalCachingClient(client: WaniKaniAPIClient,
                                         reachability: Reachability) -> LocalCachingClient {
      LocalCachingClient(client: client, reachability: reachability)
    }
  }

#else

  // In debug mode this class detects whether the app is being run under "fastlane snapshot", and
  // if so will provide a LocalCachingClient that returns fake data for taking screenshots for the
  // app store.
  @objc(TKMScreenshotter)
  @objcMembers
  class Screenshotter: NSObject {
    static let isActive: Bool = {
      UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT")
    }()

    class func setUp() {
      if isActive {
        if ProcessInfo.processInfo.arguments.contains("ResetUserDefaults") {
          // We're run again after testing finishes to remove the dummy user.
          Settings.userCookie = ""
          Settings.userApiToken = ""
          Settings.userEmailAddress = ""
        } else {
          // Pretend there's a logged in user.
          Settings.userCookie = "dummy"
          Settings.userApiToken = "dummy"
          Settings.userEmailAddress = "dummy"
          Settings.showSRSLevelIndicator = true
        }
      }
    }

    static func createLocalCachingClient(client: WaniKaniAPIClient,
                                         reachability: Reachability) -> LocalCachingClient {
      isActive ? FakeLocalCachingClient(client: client, reachability: reachability)
        : LocalCachingClient(client: client, reachability: reachability)
    }
  }

  class FakeLocalCachingClient: LocalCachingClient {
    private let subjectTextProtos: [Int32: String] = [
      // Subjects used in the search results for "sake". Abridged protos containing just the fields
      // displayed in search results.
      743: """
        id: 743
        level: 10
        japanese: "酒"
        readings {
          reading: "しゅ"
          is_primary: true
          type: ONYOMI
        }
        readings {
          reading: "さけ"
          is_primary: false
          type: KUNYOMI
        }
        readings {
          reading: "さか"
          is_primary: false
          type: KUNYOMI
        }
        meanings {
          meaning: "Alcohol"
          type: PRIMARY
        }
        kanji {}
      """,

      3163: """
        id: 3163
        level: 10
        japanese: "お酒"
        readings {
          reading: "おさけ"
          is_primary: true
        }
        meanings {
          meaning: "Sake"
          type: PRIMARY
        }
        meanings {
          meaning: "Alcohol"
          type: SECONDARY
        }
        vocabulary {}
      """,

      3164: """
        id: 3164
        level: 10
        japanese: "日本酒"
        readings {
          reading: "にほんしゅ"
          is_primary: true
        }
        readings {
          reading: "にっぽんしゅ"
          is_primary: false
        }
        meanings {
          meaning: "Japanese Style Alcohol"
          type: PRIMARY
        }
        meanings {
          meaning: "Japanese Alcohol"
          type: SECONDARY
        }
        meanings {
          meaning: "Sake"
          type: SECONDARY
        }
        vocabulary {}
      """,

      355: """
        id: 355
        level: 35
        japanese: "為"
        meanings {
          meaning: "Sake"
          type: PRIMARY
        }
        meanings {
          meaning: "fake"
          type: BLACKLIST
        }
        radical {}
      """,

      1600: """
        id: 1600
        level: 35
        japanese: "為"
        readings {
          reading: "い"
          is_primary: true
          type: ONYOMI
        }
        readings {
          reading: "ため"
          is_primary: false
          type: KUNYOMI
        }
        readings {
          reading: "な"
          is_primary: false
          type: KUNYOMI
        }
        readings {
          reading: "す"
          is_primary: false
          type: KUNYOMI
        }
        meanings {
          meaning: "Sake"
          type: PRIMARY
        }
        meanings {
          meaning: "Fake"
          type: BLACKLIST
        }
        kanji {}
      """,

      8911: """
        id: 8911
        level: 36
        japanese: "鮭"
        readings {
          reading: "さけ"
          is_primary: true
          type: KUNYOMI
        }
        readings {
          reading: "しゃけ"
          is_primary: true
          type: KUNYOMI
        }
        meanings {
          meaning: "Salmon"
          type: PRIMARY
        }
        kanji {
      """,

      8918: """
        id: 8918
        level: 36
        japanese: "鮭"
        readings {
          reading: "さけ"
          is_primary: true
        }
        readings {
          reading: "しゃけ"
          is_primary: false
        }
        meanings {
          meaning: "Salmon"
          type: PRIMARY
        }
        vocabulary {}
      """,

      1787: """
        id: 1787
        level: 41
        japanese: "酎"
        readings {
          reading: "ちゅう"
          is_primary: true
          type: ONYOMI
        }
        readings {
          reading: "ちゅ"
          is_primary: true
          type: ONYOMI
        }
        readings {
          reading: "かも"
          is_primary: false
          type: KUNYOMI
        }
        meanings {
          meaning: "Sake"
          type: PRIMARY
        }
        kanji {}
      """,

      1803: """
        id: 1803
        level: 41
        japanese: "偽"
        readings {
          reading: "ぎ"
          is_primary: true
          type: ONYOMI
        }
        readings {
          reading: "にせ"
          is_primary: false
          type: KUNYOMI
        }
        readings {
          reading: "いつわ"
          is_primary: false
          type: KUNYOMI
        }
        meanings {
          meaning: "Fake"
          type: PRIMARY
        }
        meanings {
          meaning: "Sake"
          type: BLACKLIST
        }
        kanji {}
      """,

      6556: """
        id: 6556
        level: 41
        japanese: "偽"
        readings {
          reading: "にせ"
          is_primary: true
        }
        meanings {
          meaning: "Fake"
          type: PRIMARY
        }
        meanings {
          meaning: "Imitation"
          type: SECONDARY
        }
        meanings {
          meaning: "Sake"
          type: BLACKLIST
        }
        vocabulary {}
      """,

      1892: """
        id: 1892
        level: 44
        japanese: "叫"
        readings {
          reading: "きょう"
          is_primary: true
          type: ONYOMI
        }
        readings {
          reading: "さけ"
          is_primary: false
          type: KUNYOMI
        }
        meanings {
          meaning: "Shout"
          type: PRIMARY
        }
        kanji {}
      """,

      3516: """
        id: 3516
        level: 12
        japanese: "酒飲み"
        readings {
          reading: "さけのみ"
          is_primary: true
        }
        meanings {
          meaning: "Alcoholic"
          type: PRIMARY
        }
        meanings {
          meaning: "Boozer"
          type: SECONDARY
        }
        meanings {
          meaning: "Drunkard"
          type: SECONDARY
        }
        meanings {
          meaning: "Big Drinker"
          type: AUXILIARY_WHITELIST
        }
        meanings {
          meaning: "Drinker"
          type: AUXILIARY_WHITELIST
        }
        meanings {
          meaning: "Drink"
          type: BLACKLIST
        }
        meanings {
          meaning: "alcohol"
          type: BLACKLIST
        }
        vocabulary {}
      """,

      3515: """
        id: 3515
        level: 13
        japanese: "酒好き"
        readings {
          reading: "さけずき"
          is_primary: true
        }
        meanings {
          meaning: "Drinker"
          type: PRIMARY
        }
        meanings {
          meaning: "Alcoholic"
          type: SECONDARY
        }
        vocabulary {}
      """,

      5907: """
        id: 5907
        level: 35
        japanese: "為に"
        readings {
          reading: "ために"
          is_primary: true
        }
        meanings {
          meaning: "For"
          type: PRIMARY
        }
        meanings {
          meaning: "For The Sake Of"
          type: SECONDARY
        }
        meanings {
          meaning: "To"
          type: SECONDARY
        }
        meanings {
          meaning: "Sake Of"
          type: SECONDARY
        }
        vocabulary {}
      """,

      6163: """
        id: 6163
        level: 38
        japanese: "避ける"
        readings {
          reading: "さける"
          is_primary: true
        }
        readings {
          reading: "よける"
          is_primary: false
        }
        meanings {
          meaning: "To Avoid"
          type: PRIMARY
        }
        meanings {
          meaning: "To Dodge"
          type: SECONDARY
        }
        vocabulary {}
      """,

      6812: """
        id: 6812
        level: 44
        japanese: "叫ぶ"
        readings {
          reading: "さけぶ"
          is_primary: true
        }
        meanings {
          meaning: "To Shout"
          type: PRIMARY
        }
        meanings {
          meaning: "To Scream"
          type: SECONDARY
        }
        vocabulary {}
      """,

      6960: """
        id: 6960
        level: 46
        japanese: "叫び"
        readings {
          reading: "さけび"
          is_primary: true
        }
        meanings {
          meaning: "Shout"
          type: PRIMARY
        }
        meanings {
          meaning: "Scream"
          type: SECONDARY
        }
        meanings {
          meaning: "A Shout"
          type: SECONDARY
        }
        meanings {
          meaning: "A Scream"
          type: SECONDARY
        }
        vocabulary {}
      """,

      6961: """
        id: 6961
        level: 46
        japanese: "叫び声"
        readings {
          reading: "さけびごえ"
          is_primary: true
        }
        meanings {
          meaning: "Shout"
          type: PRIMARY
        }
        meanings {
          meaning: "Yell"
          type: SECONDARY
        }
        meanings {
          meaning: "Scream"
          type: SECONDARY
        }
        vocabulary {}
      """,

      // Full proto for the subject details view.
      3864: """
        id: 3864
        level: 8
        slug: "私自身"
        document_url: "https://www.wanikani.com/vocabulary/%E7%A7%81%E8%87%AA%E8%BA%AB"
        japanese: "私自身"
        readings {
          reading: "わたしじしん"
          is_primary: true
        }
        readings {
          reading: "わたくしじしん"
          is_primary: false
        }
        meanings {
          meaning: "Personally"
          type: PRIMARY
        }
        meanings {
          meaning: "As For Me"
          type: SECONDARY
        }
        meanings {
          meaning: "Myself"
          type: SECONDARY
        }
        component_subject_ids: [923, 578, 689]
        vocabulary {
          meaning_explanation: "\\"When it comes to <kanji>somebody</kanji> like my<kanji>self</kanji>... aka <kanji>I</kanji>...\\" When you say this you're really saying \\"<vocabulary>personally</vocabulary>\\" or \\"<vocabulary>as for me</vocabulary>.\\""
          reading_explanation: "The readings are a bit weird here. The <ja>私</ja> is <ja>わたし</ja> and the rest is on'yomi kanji readings. So, it's a mix of both, I'm afraid. \\"When it comes to me, I like mixing up on'yomi and kun'yomi because I hate myself.\\""
          sentences {
            japanese: "私自身は、その動物園の問題にはあまり関心がないんです。"
            english: "Personally, I'm indifferent to the zoo's issues."
          }
          sentences {
            japanese: "私自身は、そんなにきょくたんなことじゃなければ、どんな食生活でも良いと思っています。"
            english: "As for me, as long as it isn't too extreme, I think any kind of diet is okay."
          }
          sentences {
            japanese: "あなたがもし私自身よりも私のことを知っていると思ったら、 それはとんだ大間違いよ。"
            english: "You’re way off base if you think you know me better than I know myself."
          }
          parts_of_speech: [PRONOUN]
          audio_ids: [41385, 41377, 6643, 29636]
        }
      """,

      // Component subject IDs in the above.
      923: """
        id: 923
        japanese: "私"
        meanings {
          meaning: "I"
          type: PRIMARY
        }
        kanji {}
      """,

      578: """
        id: 578
        japanese: "自"
        meanings {
          meaning: "Self"
          type: PRIMARY
        }
        kanji {}
      """,

      689: """
        id: 689
        japanese: "身"
        meanings {
          meaning: "Somebody"
          type: PRIMARY
        }
        kanji {}
      """,

      // Catalogue view by level. All radicals and kanji for level 24, with just enough info for the
      // list view.
      293: """
        id: 293
        level: 24
        japanese: "旦"
        meanings {
          meaning: "Dawn"
          type: PRIMARY
        }
        meanings {
          meaning: "Sunrise"
          type: AUXILIARY_WHITELIST
        }
        radical {}
      """,

      294: """
        id: 294
        level: 24
        japanese: "韋"
        meanings {
          meaning: "Korea"
          type: PRIMARY
        }
        meanings {
          meaning: "Cow God"
          type: AUXILIARY_WHITELIST
        }
        radical {}
      """,

      295: """
        id: 295
        level: 24
        japanese: "客"
        meanings {
          meaning: "Guest"
          type: PRIMARY
        }
        radical {}
      """,

      296: """
        id: 296
        level: 24
        japanese: "制"
        meanings {
          meaning: "Control"
          type: PRIMARY
        }
        radical {}
      """,

      297: """
        id: 297
        level: 24
        japanese: "然"
        meanings {
          meaning: "Nature"
          type: PRIMARY
        }
        radical {}
      """,

      298: """
        id: 298
        level: 24
        japanese: "受"
        meanings {
          meaning: "Accept"
          type: PRIMARY
        }
        radical {}
      """,

      1217: """
        id: 1217
        level: 24
        japanese: "担"
        readings {
          reading: "たん"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Carry"
          type: PRIMARY
        }
        meanings {
          meaning: "Bear"
          type: SECONDARY
        }
        kanji {}
      """,

      1218: """
        id: 1218
        level: 24
        japanese: "額"
        readings {
          reading: "がく"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Amount"
          type: PRIMARY
        }
        meanings {
          meaning: "Framed Picture"
          type: SECONDARY
        }
        meanings {
          meaning: "Forehead"
          type: SECONDARY
        }
        kanji {}
      """,

      1219: """
        id: 1219
        level: 24
        japanese: "製"
        readings {
          reading: "せい"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Manufacture"
          type: PRIMARY
        }
        kanji {}
      """,

      1220: """
        id: 1220
        level: 24
        japanese: "違"
        readings {
          reading: "ちが"
          is_primary: true
          type: KUNYOMI
        }
        meanings {
          meaning: "Different"
          type: PRIMARY
        }
        kanji {}
      """,

      1221: """
        id: 1221
        level: 24
        japanese: "輸"
        readings {
          reading: "ゆ"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Transport"
          type: PRIMARY
        }
        kanji {}
      """,

      1222: """
        id: 1222
        level: 24
        japanese: "燃"
        readings {
          reading: "ねん"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Burn"
          type: PRIMARY
        }
        kanji {}
      """,

      1223: """
        id: 1223
        level: 24
        japanese: "祝"
        readings {
          reading: "しゅく"
          is_primary: true
          type: ONYOMI
        }
        readings {
          reading: "しゅう"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Celebrate"
          type: PRIMARY
        }
        kanji {}
      """,

      1224: """
        id: 1224
        level: 24
        japanese: "届"
        readings {
          reading: "とど"
          is_primary: true
          type: KUNYOMI
        }
        meanings {
          meaning: "Deliver"
          type: PRIMARY
        }
        kanji {}
      """,

      1225: """
        id: 1225
        level: 24
        japanese: "狭"
        readings {
          reading: "せま"
          is_primary: true
          type: KUNYOMI
        }
        readings {
          reading: "せば"
          is_primary: true
          type: KUNYOMI
        }
        meanings {
          meaning: "Narrow"
          type: PRIMARY
        }
        kanji {}
      """,

      1226: """
        id: 1226
        level: 24
        japanese: "肩"
        readings {
          reading: "かた"
          is_primary: true
          type: KUNYOMI
        }
        meanings {
          meaning: "Shoulder"
          type: PRIMARY
        }
        kanji {}
      """,

      1227: """
        id: 1227
        level: 24
        japanese: "腕"
        readings {
          reading: "うで"
          is_primary: true
          type: KUNYOMI
        }
        meanings {
          meaning: "Arm"
          type: PRIMARY
        }
        kanji {}
      """,

      1228: """
        id: 1228
        level: 24
        japanese: "腰"
        readings {
          reading: "こし"
          is_primary: true
          type: KUNYOMI
        }
        meanings {
          meaning: "Waist"
          type: PRIMARY
        }
        kanji {}
      """,

      1229: """
        id: 1229
        level: 24
        japanese: "触"
        readings {
          reading: "しょく"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Touch"
          type: PRIMARY
        }
        kanji {}
      """,

      1230: """
        id: 1230
        level: 24
        japanese: "載"
        readings {
          reading: "さい"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Publish"
          type: PRIMARY
        }
        kanji {}
      """,

      1231: """
        id: 1231
        level: 24
        japanese: "層"
        readings {
          reading: "そう"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Layer"
          type: PRIMARY
        }
        kanji {}
      """,

      1232: """
        id: 1232
        level: 24
        japanese: "型"
        readings {
          reading: "けい"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Model"
          type: PRIMARY
        }
        meanings {
          meaning: "Type"
          type: SECONDARY
        }
        kanji {}
      """,

      1233: """
        id: 1233
        level: 24
        japanese: "庁"
        readings {
          reading: "ちょう"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Agency"
          type: PRIMARY
        }
        meanings {
          meaning: "Government Office"
          type: SECONDARY
        }
        kanji {}
      """,

      1234: """
        id: 1234
        level: 24
        japanese: "視"
        readings {
          reading: "し"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Look At"
          type: PRIMARY
        }
        kanji {}
      """,

      1235: """
        id: 1235
        level: 24
        japanese: "差"
        readings {
          reading: "さ"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Distinction"
          type: PRIMARY
        }
        kanji {}
      """,

      1236: """
        id: 1236
        level: 24
        japanese: "管"
        readings {
          reading: "かん"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Pipe"
          type: PRIMARY
        }
        kanji {}
      """,

      1237: """
        id: 1237
        level: 24
        japanese: "象"
        readings {
          reading: "ぞう"
          is_primary: true
          type: ONYOMI
        }
        readings {
          reading: "しょう"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Elephant"
          type: PRIMARY
        }
        meanings {
          meaning: "Phenomenon"
          type: SECONDARY
        }
        kanji {}
      """,

      1238: """
        id: 1238
        level: 24
        japanese: "量"
        readings {
          reading: "りょう"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Quantity"
          type: PRIMARY
        }
        meanings {
          meaning: "Amount"
          type: SECONDARY
        }
        meanings {
          meaning: "quality"
          type: BLACKLIST
        }
        kanji {}
      """,

      1239: """
        id: 1239
        level: 24
        japanese: "境"
        readings {
          reading: "きょう"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Boundary"
          type: PRIMARY
        }
        kanji {}
      """,

      1240: """
        id: 1240
        level: 24
        japanese: "環"
        readings {
          reading: "かん"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Loop"
          type: PRIMARY
        }
        kanji {}
      """,

      1241: """
        id: 1241
        level: 24
        japanese: "武"
        readings {
          reading: "ぶ"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Military"
          type: PRIMARY
        }
        kanji {}
      """,

      1242: """
        id: 1242
        level: 24
        japanese: "質"
        readings {
          reading: "しつ"
          is_primary: true
          type: ONYOMI
        }
        readings {
          reading: "しち"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Quality"
          type: PRIMARY
        }
        kanji {}
      """,

      1243: """
        id: 1243
        level: 24
        japanese: "述"
        readings {
          reading: "じゅつ"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Mention"
          type: PRIMARY
        }
        kanji {}
      """,

      1244: """
        id: 1244
        level: 24
        japanese: "供"
        readings {
          reading: "きょう"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Servant"
          type: PRIMARY
        }
        meanings {
          meaning: "Companion"
          type: SECONDARY
        }
        kanji {}
      """,

      1245: """
        id: 1245
        level: 24
        japanese: "展"
        readings {
          reading: "てん"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Expand"
          type: PRIMARY
        }
        kanji {}
      """,

      1246: """
        id: 1246
        level: 24
        japanese: "販"
        readings {
          reading: "はん"
          is_primary: true
          type: ONYOMI
        }
        meanings {
          meaning: "Sell"
          type: PRIMARY
        }
        kanji {}
      """,

      1247: """
        id: 1247
        level: 24
        japanese: "株"
        readings {
          reading: "かぶ"
          is_primary: true
          type: KUNYOMI
        }
        meanings {
          meaning: "Stocks"
          type: PRIMARY
        }
        meanings {
          meaning: "Shares"
          type: SECONDARY
        }
        kanji {}
      """,

      8790: """
        id: 8790
        level: 24
        meanings {
          meaning: "Death Star"
          type: PRIMARY
        }
        radical {
          character_image: "https://cdn.wanikani.com/images/363-subject-8790-with-css-original.svg?1520987154"
          has_character_image_file: true
        }
      """,
    ]

    override func countRows(inTable _: String) -> Int {
      0
    }

    override func updateAvailableSubjects() -> (Int, Int, [Int]) {
      return (10, 4, [14, 8, 2, 1, 12, 42, 17, 9, 2, 0, 2, 17, 0, 0, 6, 0, 0, 0, 0, 4, 11, 0, 8,
                      6])
    }

    override func updateGuruKanjiCount() -> Int {
      864
    }

    override func updateSrsCategoryCounts() -> [Int] {
      [86, 120, 485, 786, 2056]
    }

    override func getSubject(id: Int32) -> TKMSubject? {
      if let textProto = subjectTextProtos[id] {
        return try! TKMSubject(textFormatString: textProto)
      }
      return nil
    }

    override func getAllAssignments() -> [TKMAssignment] {
      // Return some assignments for a review.
      var a = TKMAssignment()
      a.subjectID = 3864
      a.subjectType = .vocabulary
      a.availableAt = 42
      a.srsStageNumber = 2
      return Array(repeating: a, count: Int(availableSubjects.reviewCount))
    }

    override func getStudyMaterial(subjectId _: Int32) -> TKMStudyMaterials? {
      nil
    }

    override func getUserInfo() -> TKMUser? {
      var user = TKMUser()
      user.level = 24
      user.username = "Fred"
      user.maxLevelGrantedBySubscription = 60
      return user
    }

    override func getAllPendingProgress() -> [TKMProgress] {
      []
    }

    override func getAssignment(subjectId _: Int32) -> TKMAssignment? {
      nil
    }

    override func getAssignments(level _: Int) -> [TKMAssignment] {
      // Return just enough to populate the SubjectsByLevelViewController.
      let subjects = [293,
                      294,
                      295,
                      296,
                      297,
                      298,
                      1217,
                      1218,
                      1219,
                      1220,
                      1221,
                      1222,
                      1223,
                      1224,
                      1225,
                      1226,
                      1227,
                      1228,
                      1229,
                      1230,
                      1231,
                      1232,
                      1233,
                      1234,
                      1235,
                      1236,
                      1237,
                      1238,
                      1239,
                      1240,
                      1241,
                      1242,
                      1243,
                      1244,
                      1245,
                      1246,
                      1247,
                      8790].map {
        getSubject(id: $0)!
      }

      srand48(42)

      var ret = [TKMAssignment]()
      for s in subjects {
        var a = TKMAssignment()
        a.subjectID = s.id
        a.subjectType = s.subjectType

        if a.subjectType == .radical {
          a.srsStageNumber = 5
        } else {
          a.srsStageNumber = Int32(drand48() * 6)
        }
        ret.append(a)
      }
      return ret
    }

    override func getAssignmentsAtUsersCurrentLevel() -> [TKMAssignment] {
      makePieSlices(.radical, locked: 0, lesson: 2, apprentice: 4, guru: 1) +
        makePieSlices(.kanji, locked: 8, lesson: 4, apprentice: 12, guru: 1) +
        makePieSlices(.vocabulary, locked: 50, lesson: 8, apprentice: 4, guru: 0)
    }

    override func sendProgress(_: [TKMProgress]) -> Promise<Void> {
      Promise.value(())
    }

    override func updateStudyMaterial(_: TKMStudyMaterials) -> Promise<Void> {
      Promise.value(())
    }

    override func clearAllData() {}

    override func clearAllDataAndClose() {}

    private func makeAssignment(_ type: TKMSubject.TypeEnum, srsStage: Int32) -> TKMAssignment {
      var ret = TKMAssignment()
      ret.subjectType = type
      if srsStage != -1 {
        ret.srsStageNumber = srsStage
      }
      return ret
    }

    private func makePieSlices(_ type: TKMSubject.TypeEnum,
                               locked: Int,
                               lesson: Int,
                               apprentice: Int,
                               guru: Int) -> [TKMAssignment] {
      Array(repeating: makeAssignment(type, srsStage: -1), count: locked) +
        Array(repeating: makeAssignment(type, srsStage: 0), count: lesson) +
        Array(repeating: makeAssignment(type, srsStage: 1), count: apprentice) +
        Array(repeating: makeAssignment(type, srsStage: 6), count: guru)
    }

    override func sync(quick _: Bool, progress _: Progress) -> PMKFinalizer {
      Promise.value(()).cauterize()
    }
  }

#endif
