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

import Hippolyte

import XCTest

class APIClientTest: XCTestCase {
  var client: WaniKaniAPIClient!
  var subjectLevelGetter: FakeSubjectLevelGetter!

  override func setUp() {
    subjectLevelGetter = FakeSubjectLevelGetter()

    client = WaniKaniAPIClient(apiToken: "bob")
    client.subjectLevelGetter = subjectLevelGetter

    Hippolyte.shared.start()
  }

  override class func tearDown() {
    Hippolyte.shared.stop()
  }

  func testDateParsing() {
    let parse = { (_ str: String) -> Double in
      WaniKaniDate(fromString: str)!.date.timeIntervalSince1970
    }

    XCTAssertEqual(parse("2018-08-05T11:08:39.431000Z"), 1_533_467_319.431)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431Z"), 1_533_467_319.431)
    XCTAssertEqual(parse("2018-08-05T11:08:39.000000Z"), 1_533_467_319.0)
    XCTAssertEqual(parse("2018-08-05T11:08:39.000Z"), 1_533_467_319.0)
    XCTAssertEqual(parse("20180805T11:08:39.431000Z"), 1_533_467_319.431)
    XCTAssertEqual(parse("2018-08-05T11:08:39Z"), 1_533_467_319.0)
    XCTAssertEqual(parse("20180805T11:08:39Z"), 1_533_467_319.0)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431000+03:00"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431000+0300"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431000+03"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431+03:00"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431+0300"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39.431+03"), 1_533_467_319.431 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39+03:00"), 1_533_467_319.0 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39+0300"), 1_533_467_319.0 - 3 * 60 * 60)
    XCTAssertEqual(parse("2018-08-05T11:08:39+03"), 1_533_467_319.0 - 3 * 60 * 60)
  }

  func testUser() {
    var request = StubRequest(method: .GET, url: URL(string: "https://api.wanikani.com/v2/user")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "user",
      "url": "https://api.wanikani.com/v2/user",
      "data_updated_at": "2018-04-06T14:26:53.022245Z",
      "data": {
        "id": "5a6a5234-a392-4a87-8f3f-33342afe8a42",
        "username": "example_user",
        "level": 5,
        "profile_url": "https://www.wanikani.com/users/example_user",
        "started_at": "2012-05-11T00:52:18.958466Z",
        "current_vacation_started_at": null,
        "subscription": {
          "active": true,
          "type": "recurring",
          "max_level_granted": 60,
          "period_ends_at": "2018-12-11T13:32:19.485748Z"
        },
        "preferences": {
          "default_voice_actor_id": 1,
          "lessons_autoplay_audio": false,
          "lessons_batch_size": 10,
          "lessons_presentation_order": "ascending_level_then_subject",
          "reviews_autoplay_audio": false,
          "reviews_display_srs_indicator": true
        }
      }
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let expected = try! TKMUser(textFormatString: """
      username: "example_user"
      level: 5
      max_level_granted_by_subscription: 60
      profile_url: "https://www.wanikani.com/users/example_user"
      started_at: 1336697538
      subscribed: true
      subscription_ends_at: 1544535139
    """)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.user(progress: progress)) {
      XCTAssertEqual(result, expected)
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testAllAssignments() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/assignments" +
                                "?unlocked=true&hidden=false")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/assignments",
      "pages": {
        "per_page": 500,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 1600,
      "data_updated_at": "2017-11-29T19:37:03.571377Z",
      "data": [
        {
          "id": 80463006,
          "object": "assignment",
          "url": "https://api.wanikani.com/v2/assignments/80463006",
          "data_updated_at": "2017-10-30T01:51:10.438432Z",
          "data": {
            "created_at": "2017-09-05T23:38:10.695133Z",
            "subject_id": 8761,
            "subject_type": "radical",
            "srs_stage": 8,
            "unlocked_at": "2017-09-05T23:38:10.695133Z",
            "started_at": "2017-09-05T23:41:28.980679Z",
            "passed_at": "2017-09-07T17:14:14.491889Z",
            "burned_at": null,
            "available_at": "2018-02-27T00:00:00.000000Z",
            "resurrected_at": null
          }
        }
      ]
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let expected = try! TKMAssignment(textFormatString: """
      id: 80463006
      level: 42
      subject_id: 8761
      subject_type: RADICAL
      available_at: 1519689600
      started_at: 1504654888
      srs_stage_number: 8
      passed_at: 1504804454
    """)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.assignments(progress: progress)) {
      XCTAssertEqual(result.assignments.count, 1)
      XCTAssertEqual(result.assignments[0], expected)
      XCTAssertEqual(result.updatedAt, "2017-11-29T19:37:03.571377Z")
    }
    XCTAssertEqual(progress.totalUnitCount, 4)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testAssignmentsUpdatedAfter() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/assignments" +
                                "?unlocked=true&hidden=false&updated_after=foobar")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/assignments",
      "pages": {
        "per_page": 500,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 1600,
      "data_updated_at": "2017-11-29T19:37:03.571377Z",
      "data": []
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.assignments(progress: progress, updatedAfter: "foobar")) {
      XCTAssertEqual(result.assignments.count, 0)
      XCTAssertEqual(result.updatedAt, "2017-11-29T19:37:03.571377Z")
    }
    XCTAssertEqual(progress.totalUnitCount, 4)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testAssignmentsUpdatedAfterNoResults() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/assignments" +
                                "?unlocked=true&hidden=false&updated_after=foobar")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/assignments",
      "pages": {
        "per_page": 500,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 0,
      "data_updated_at": null,
      "data": []
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.assignments(progress: progress, updatedAfter: "foobar")) {
      XCTAssertEqual(result.assignments.count, 0)
      XCTAssertEqual(result.updatedAt, "foobar")
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testAssignmentPagination() {
    var request1 = StubRequest(method: .GET,
                               url: URL(string: "https://api.wanikani.com/v2/assignments" +
                                 "?unlocked=true&hidden=false")!)
    request1.setHeader(key: "Authorization", value: "Token token=bob")
    request1.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/assignments",
      "pages": {
        "per_page": 500,
        "next_url": "https://api.wanikani.com/v2/assignments?page_after_id=80469434",
        "previous_url": null
      },
      "total_count": 1600,
      "data_updated_at": "first-updated-at",
      "data": [
        {
          "id": 42,
          "object": "assignment",
          "url": "https://api.wanikani.com/v2/assignments/80463006",
          "data_updated_at": "2017-10-30T01:51:10.438432Z",
          "data": {
            "created_at": "2017-09-05T23:38:10.695133Z",
            "subject_id": 42,
            "subject_type": "radical",
            "srs_stage": 8,
            "unlocked_at": "2017-09-05T23:38:10.695133Z",
            "started_at": "2017-09-05T23:41:28.980679Z",
            "passed_at": "2017-09-07T17:14:14.491889Z",
            "burned_at": null,
            "available_at": "2018-02-27T00:00:00.000000Z",
            "resurrected_at": null
          }
        }
      ]
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request1)

    var request2 = StubRequest(method: .GET,
                               url: URL(string: "https://api.wanikani.com/v2/assignments" +
                                 "?page_after_id=80469434")!)
    request2.setHeader(key: "Authorization", value: "Token token=bob")
    request2.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/assignments",
      "pages": {
        "per_page": 500,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 1600,
      "data_updated_at": "second-updated-at",
      "data": [
        {
          "id": 43,
          "object": "assignment",
          "url": "https://api.wanikani.com/v2/assignments/80463006",
          "data_updated_at": "2017-10-30T01:51:10.438432Z",
          "data": {
            "created_at": "2017-09-05T23:38:10.695133Z",
            "subject_id": 43,
            "subject_type": "radical",
            "srs_stage": 8,
            "unlocked_at": "2017-09-05T23:38:10.695133Z",
            "started_at": "2017-09-05T23:41:28.980679Z",
            "passed_at": "2017-09-07T17:14:14.491889Z",
            "burned_at": null,
            "available_at": "2018-02-27T00:00:00.000000Z",
            "resurrected_at": null
          }
        }
      ]
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request2)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.assignments(progress: progress)) {
      XCTAssertEqual(result.assignments.count, 2)
      XCTAssertEqual(result.assignments[0].id, 42)
      XCTAssertEqual(result.assignments[1].id, 43)
      XCTAssertEqual(result.updatedAt, "second-updated-at")
    }
    XCTAssertEqual(progress.totalUnitCount, 4)
    XCTAssertEqual(progress.completedUnitCount, 2)
  }

  func testAllStudyMaterials() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/study_materials")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/study_materials",
      "pages": {
        "per_page": 500,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 88,
      "data_updated_at": "2017-12-21T22:42:11.468155Z",
      "data": [
        {
          "id": 65231,
          "object": "study_material",
          "url": "https://api.wanikani.com/v2/study_materials/65231",
          "data_updated_at": "2017-09-30T01:42:13.453291Z",
          "data": {
            "created_at": "2017-09-30T01:42:13.453291Z",
            "subject_id": 241,
            "subject_type": "radical",
            "meaning_note": "I like turtles",
            "reading_note": "I like durtles",
            "meaning_synonyms": ["burn", "sizzle"]
          }
        }
      ]
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let expected = try! TKMStudyMaterials(textFormatString: """
      id: 65231
      subject_id: 241
      meaning_note: "I like turtles"
      reading_note: "I like durtles"
      meaning_synonyms: "burn"
      meaning_synonyms: "sizzle"
    """)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.studyMaterials(progress: progress)) {
      XCTAssertEqual(result.studyMaterials.count, 1)
      XCTAssertEqual(result.studyMaterials[0], expected)
      XCTAssertEqual(result.updatedAt, "2017-12-21T22:42:11.468155Z")
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testStudyMaterialsUpdatedAfter() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/study_materials" +
                                "?updated_after=foobar")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/study_materials",
      "pages": {
        "per_page": 500,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 88,
      "data_updated_at": "2017-12-21T22:42:11.468155Z",
      "data": []
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client
      .studyMaterials(progress: progress, updatedAfter: "foobar")) {
      XCTAssertEqual(result.studyMaterials.count, 0)
      XCTAssertEqual(result.updatedAt, "2017-12-21T22:42:11.468155Z")
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testStudyMaterialBySubjectId() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/study_materials" +
                                "?subject_ids=65231")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/study_materials",
      "pages": {
        "per_page": 500,
        "next_url": "https://api.wanikani.com/v2/study_materials?page_after_id=52342",
        "previous_url": null
      },
      "total_count": 88,
      "data_updated_at": "2017-12-21T22:42:11.468155Z",
      "data": [
        {
          "id": 65231,
          "object": "study_material",
          "url": "https://api.wanikani.com/v2/study_materials/65231",
          "data_updated_at": "2017-09-30T01:42:13.453291Z",
          "data": {
            "created_at": "2017-09-30T01:42:13.453291Z",
            "subject_id": 241,
            "subject_type": "radical",
            "meaning_note": "I like turtles",
            "reading_note": "I like durtles",
            "meaning_synonyms": ["burn", "sizzle"]
          }
        }
      ]
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let expected = try! TKMStudyMaterials(textFormatString: """
      id: 65231
      subject_id: 241
      meaning_note: "I like turtles"
      reading_note: "I like durtles"
      meaning_synonyms: "burn"
      meaning_synonyms: "sizzle"
    """)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.studyMaterial(subjectId: 65231, progress: progress)) {
      XCTAssertEqual(result, expected)
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testStudyMaterialBySubjectIdNoResult() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/study_materials" +
                                "?subject_ids=65231")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/study_materials",
      "pages": {
        "per_page": 500,
        "next_url": "https://api.wanikani.com/v2/study_materials?page_after_id=52342",
        "previous_url": null
      },
      "total_count": 88,
      "data_updated_at": "2017-12-21T22:42:11.468155Z",
      "data": []
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.studyMaterial(subjectId: 65231, progress: progress)) {
      XCTAssertNil(result)
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testAllLevelProgressions() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/level_progressions")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/level_progressions",
      "pages": {
        "per_page": 500,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 42,
      "data_updated_at": "2017-09-21T11:45:01.691388Z",
      "data": [
        {
          "id": 49392,
          "object": "level_progression",
          "url": "https://api.wanikani.com/v2/level_progressions/49392",
          "data_updated_at": "2017-03-30T11:31:20.438432Z",
          "data": {
            "created_at": "2017-03-30T08:21:51.439918Z",
            "level": 42,
            "unlocked_at": "2017-03-30T08:21:51.439918Z",
            "started_at": "2017-03-30T11:31:20.438432Z",
            "passed_at": null,
            "completed_at": null,
            "abandoned_at": null
          }
        }
      ]
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let expected = try! TKMLevel(textFormatString: """
      id: 49392
      level: 42
      created_at: 1490862111
      started_at: 1490873480
      unlocked_at: 1490862111
    """)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.levelProgressions(progress: progress)) {
      XCTAssertEqual(result.levels.count, 1)
      XCTAssertEqual(result.levels[0], expected)
      XCTAssertEqual(result.updatedAt, "2017-09-21T11:45:01.691388Z")
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testLevelProgressionsUpdatedAfter() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/level_progressions" +
                                "?updated_after=foobar")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/level_progressions",
      "pages": {
        "per_page": 500,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 42,
      "data_updated_at": "2017-09-21T11:45:01.691388Z",
      "data": []
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client
      .levelProgressions(progress: progress, updatedAfter: "foobar")) {
      XCTAssertEqual(result.levels.count, 0)
      XCTAssertEqual(result.updatedAt, "2017-09-21T11:45:01.691388Z")
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testStartAssignment() {
    let progress = try! TKMProgress(textFormatString: """
      assignment {
        id: 42
      }
      is_lesson: true
      created_at: 123456789
    """)

    var request = StubRequest(method: .PUT,
                              url: URL(string: "https://api.wanikani.com/v2/assignments/42/start")!)
    request
      .bodyMatcher = DataMatcher(data: "{\"started_at\":\"1973-11-29T21:33:09.000000Z\"}"
        .data(using: .utf8)!)
    request.setHeader(key: "Content-Type", value: "application/json")
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "id": 42,
      "object": "assignment",
      "url": "https://api.wanikani.com/v2/assignments/42",
      "data_updated_at": "2017-11-29T19:37:03.571377Z",
      "data": {
        "created_at": "2017-09-05T23:38:10.695133Z",
        "subject_id": 8761,
        "subject_type": "radical",
        "level": 1,
        "srs_stage": 1,
        "unlocked_at": "2017-09-05T23:38:10.695133Z",
        "started_at": "2017-09-05T23:41:28.980679Z",
        "passed_at": null,
        "burned_at": null,
        "available_at": "2018-02-27T00:00:00.000000Z",
        "resurrected_at": null
      }
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let expected = try! TKMAssignment(textFormatString: """
      id: 42
      level: 42
      subject_id: 8761
      subject_type: RADICAL
      available_at: 1519689600
      started_at: 1504654888
      srs_stage_number: 1
    """)

    if let result = waitForPromise(client.sendProgress(progress)) {
      XCTAssertEqual(result, expected)
    }
  }

  func testCreateReview() {
    let progress = try! TKMProgress(textFormatString: """
      assignment {
        id: 42
      }
      is_lesson: false
      created_at: 123456789
      meaning_wrong_count: 3
      reading_wrong_count: 4
    """)

    var request = StubRequest(method: .POST,
                              url: URL(string: "https://api.wanikani.com/v2/reviews")!)
    request.bodyMatcher = DataMatcher(data: ("{\"review\":{\"assignment_id\":42," +
        "\"incorrect_reading_answers\":4" +
        ",\"incorrect_meaning_answers\":3" +
        ",\"created_at\":\"1973-11-29T21:33:09.000000Z\"}}")
      .data(using: .utf8)!)
    request.setHeader(key: "Content-Type", value: "application/json")
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "id": 72,
      "object": "review",
      "url": "https://api.wanikani.com/v2/reviews/72",
      "data_updated_at": "2018-05-13T03:34:54.000000Z",
      "data": {
        "created_at": "2018-05-13T03:34:54.000000Z",
        "assignment_id": 1422,
        "spaced_repetition_system_id": 1,
        "subject_id": 997,
        "starting_srs_stage": 1,
        "ending_srs_stage": 1,
        "incorrect_meaning_answers": 1,
        "incorrect_reading_answers": 2
      },
      "resources_updated": {
        "assignment": {
          "id": 1422,
          "object": "assignment",
          "url": "https://api.wanikani.com/v2/assignments/1422",
          "data_updated_at": "2018-05-14T03:35:34.180006Z",
          "data": {
            "created_at": "2018-01-24T21:32:38.967244Z",
            "subject_id": 997,
            "subject_type": "vocabulary",
            "level": 2,
            "srs_stage": 1,
            "unlocked_at": "2018-01-24T21:32:39.888359Z",
            "started_at": "2018-01-24T21:52:47.926376Z",
            "passed_at": null,
            "burned_at": null,
            "available_at": "2018-05-14T07:00:00.000000Z",
            "resurrected_at": null,
            "passed": false,
            "resurrected": false,
            "hidden": false
          }
        },
        "review_statistic": {
          "id": 342,
          "object": "review_statistic",
          "url": "https://api.wanikani.com/v2/review_statistics/342",
          "data_updated_at": "2018-05-14T03:35:34.223515Z",
          "data": {
            "created_at": "2018-01-24T21:35:55.127513Z",
            "subject_id": 997,
            "subject_type": "vocabulary",
            "meaning_correct": 1,
            "meaning_incorrect": 1,
            "meaning_max_streak": 1,
            "meaning_current_streak": 1,
            "reading_correct": 1,
            "reading_incorrect": 2,
            "reading_max_streak": 1,
            "reading_current_streak": 1,
            "percentage_correct": 67,
            "hidden": false
          }
        }
      }
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let expected = try! TKMAssignment(textFormatString: """
      id: 1422
      level: 42
      subject_id: 997
      subject_type: VOCABULARY
      available_at: 1526281200
      started_at: 1516830767
      srs_stage_number: 1
    """)

    if let result = waitForPromise(client.sendProgress(progress)) {
      XCTAssertEqual(result, expected)
    }
  }

  func testCreateNewStudyMaterial() {
    let material = try! TKMStudyMaterials(textFormatString: """
      subject_id: 42
      meaning_synonyms: "foo"
      meaning_synonyms: "bar"
    """)

    var getRequest = StubRequest(method: .GET,
                                 url: URL(string: "https://api.wanikani.com/v2/study_materials?subject_ids=42")!)
    getRequest.setHeader(key: "Authorization", value: "Token token=bob")
    getRequest.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/study_materials",
      "pages": {
        "per_page": 500,
        "next_url": "https://api.wanikani.com/v2/study_materials?page_after_id=52342",
        "previous_url": null
      },
      "total_count": 88,
      "data_updated_at": "2017-12-21T22:42:11.468155Z",
      "data": []
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: getRequest)

    var postRequest = StubRequest(method: .POST,
                                  url: URL(string: "https://api.wanikani.com/v2/study_materials")!)
    postRequest
      .bodyMatcher =
      DataMatcher(data: "{\"study_material\":{\"meaning_synonyms\":[\"foo\",\"bar\"],\"subject_id\":42}}"
        .data(using: .utf8)!)
    postRequest.setHeader(key: "Content-Type", value: "application/json")
    postRequest.setHeader(key: "Authorization", value: "Token token=bob")
    Hippolyte.shared.add(stubbedRequest: postRequest)

    waitForPromise(client.updateStudyMaterial(material))
  }

  func testUpdateExistingStudyMaterial() {
    let material = try! TKMStudyMaterials(textFormatString: """
      subject_id: 42
      meaning_synonyms: "foo"
      meaning_synonyms: "bar"
    """)

    var getRequest = StubRequest(method: .GET,
                                 url: URL(string: "https://api.wanikani.com/v2/study_materials?subject_ids=42")!)
    getRequest.setHeader(key: "Authorization", value: "Token token=bob")
    getRequest.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/study_materials",
      "pages": {
        "per_page": 500,
        "next_url": "https://api.wanikani.com/v2/study_materials?page_after_id=52342",
        "previous_url": null
      },
      "total_count": 88,
      "data_updated_at": "2017-12-21T22:42:11.468155Z",
      "data": [
        {
          "id": 65231,
          "object": "study_material",
          "url": "https://api.wanikani.com/v2/study_materials/65231",
          "data_updated_at": "2017-09-30T01:42:13.453291Z",
          "data": {
            "created_at": "2017-09-30T01:42:13.453291Z",
            "subject_id": 241,
            "subject_type": "radical",
            "meaning_note": "I like turtles",
            "reading_note": "I like durtles",
            "meaning_synonyms": ["burn", "sizzle"]
          }
        }
      ]
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: getRequest)

    var postRequest = StubRequest(method: .PUT,
                                  url: URL(string: "https://api.wanikani.com/v2/study_materials/65231")!)
    postRequest
      .bodyMatcher =
      DataMatcher(data: "{\"study_material\":{\"meaning_synonyms\":[\"foo\",\"bar\"]}}"
        .data(using: .utf8)!)
    postRequest.setHeader(key: "Content-Type", value: "application/json")
    postRequest.setHeader(key: "Authorization", value: "Token token=bob")
    Hippolyte.shared.add(stubbedRequest: postRequest)

    waitForPromise(client.updateStudyMaterial(material))
  }

  func test4xxErrorResponse() {
    var request = StubRequest(method: .GET, url: URL(string: "https://api.wanikani.com/v2/user")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.statusCode = 400
    request.response.body = """
    {
      "error": "Foobar",
      "code": 400
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let progress = Progress(totalUnitCount: -1)
    if let error = waitForError(client.user(progress: progress)) {
      guard let apiError = error as? WaniKaniAPIError else {
        XCTFail("Bad error type: " + error.localizedDescription)
        return
      }

      XCTAssertEqual(apiError.code, 400)
      XCTAssertEqual(apiError.message, "Foobar")
      XCTAssertEqual(apiError.request.url!.absoluteString, "https://api.wanikani.com/v2/user")
      XCTAssertEqual(apiError.response.statusCode, 400)
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func test5xxErrorResponse() {
    var request = StubRequest(method: .GET, url: URL(string: "https://api.wanikani.com/v2/user")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.statusCode = 500
    request.response.body = """
    {
      "error": "Foobar",
      "code": 400
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let progress = Progress(totalUnitCount: -1)
    if let error = waitForError(client.user(progress: progress)) {
      guard let apiError = error as? WaniKaniAPIError else {
        XCTFail("Bad error type: " + error.localizedDescription)
        return
      }

      XCTAssertEqual(apiError.code, 500)
      XCTAssertNil(apiError.message)
      XCTAssertEqual(apiError.request.url!.absoluteString, "https://api.wanikani.com/v2/user")
      XCTAssertEqual(apiError.response.statusCode, 500)
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testJSONDecodeError() {
    var request = StubRequest(method: .GET, url: URL(string: "https://api.wanikani.com/v2/user")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = "invalid json".data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let progress = Progress(totalUnitCount: -1)
    if let error = waitForError(client.user(progress: progress)) {
      guard let apiError = error as? WaniKaniJSONDecodeError else {
        XCTFail("Bad error type: " + error.localizedDescription)
        return
      }

      XCTAssertEqual(apiError.data, request.response.body)
      XCTAssertEqual(apiError.error.localizedDescription,
                     "The data couldn’t be read because it isn’t in the correct format.")
      XCTAssertEqual(apiError.request.url!.absoluteString, "https://api.wanikani.com/v2/user")
      XCTAssertEqual(apiError.response.statusCode, 200)
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testAllSubjectsParsesOneSubject() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/subjects" +
                                "?hidden=false&page_after_id=-1")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/subjects?types=kanji",
      "pages": {
        "per_page": 1000,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 2027,
      "data_updated_at": "2018-04-09T18:08:59.946969Z",
      "data": [
        {
          "id": 440,
          "object": "kanji",
          "url": "https://api.wanikani.com/v2/subjects/440",
          "data_updated_at": "2018-03-29T23:14:30.805034Z",
          "data": {
            "created_at": "2012-02-27T19:55:19.000000Z",
            "level": 1,
            "slug": "一",
            "hidden_at": null,
            "document_url": "https://www.wanikani.com/kanji/%E4%B8%80",
            "characters": "一",
            "meanings": [
              {
                "meaning": "One",
                "primary": true,
                "accepted_answer": true
              }
            ],
            "readings": [
              {
                "type": "onyomi",
                "primary": true,
                "accepted_answer": true,
                "reading": "いち"
              },
              {
                "type": "kunyomi",
                "primary": false,
                "accepted_answer": false,
                "reading": "ひと"
              },
              {
                "type": "nanori",
                "primary": false,
                "accepted_answer": false,
                "reading": "かず"
              }
            ],
            "component_subject_ids": [
              1
            ],
            "amalgamation_subject_ids": [
              56,
              88,
              91
            ],
            "visually_similar_subject_ids": [],
            "meaning_mnemonic": "Lying on the <radical>ground</radical> is something that looks just like the ground, the number <kanji>One</kanji>. Why is this One lying down? It's been shot by the number two. It's lying there, bleeding out and dying. The number One doesn't have long to live.",
            "meaning_hint": "To remember the meaning of <kanji>One</kanji>, imagine yourself there at the scene of the crime. You grab <kanji>One</kanji> in your arms, trying to prop it up, trying to hear its last words. Instead, it just splatters some blood on your face. \\"Who did this to you?\\" you ask. The number One points weakly, and you see number Two running off into an alleyway. He's always been jealous of number One and knows he can be number one now that he's taken the real number one out.",
            "reading_mnemonic": "As you're sitting there next to <kanji>One</kanji>, holding him up, you start feeling a weird sensation all over your skin. From the wound comes a fine powder (obviously coming from the special bullet used to kill One) that causes the person it touches to get extremely <reading>itchy</reading> (いち)",
            "reading_hint": "Make sure you feel the ridiculously <reading>itchy</reading> sensation covering your body. It climbs from your hands, where you're holding the number <kanji>One</kanji> up, and then goes through your arms, crawls up your neck, goes down your body, and then covers everything. It becomes uncontrollable, and you're scratching everywhere, writhing on the ground. It's so itchy that it's the most painful thing you've ever experienced (you should imagine this vividly, so you remember the reading of this kanji).",
            "lesson_position": 2,
            "spaced_repetition_system_id": 1
          }
        }
      ]
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    // Return empty responses for the other pages.
    for pageAfterId in stride(from: 999, through: 7999, by: 1000) {
      var request = StubRequest(method: .GET,
                                url: URL(string: "https://api.wanikani.com/v2/subjects" +
                                  "?hidden=false&page_after_id=\(pageAfterId)")!)
      request.response.body = """
      {
        "object": "collection",
        "url": "https://api.wanikani.com/v2/subjects?types=kanji",
        "pages": {
          "per_page": 1000,
          "next_url": null,
          "previous_url": null
        },
        "total_count": 2027,
        "data_updated_at": "2018-04-09T18:08:59.946969Z",
        "data": []
      }
      """.data(using: .utf8)
      Hippolyte.shared.add(stubbedRequest: request)
    }

    let expected = try! TKMSubject(textFormatString: """
      id: 440
      level: 1
      slug: "一"
      document_url: "https://www.wanikani.com/kanji/%E4%B8%80"
      japanese: "一"
      readings {
        reading: "いち"
        is_primary: true
        type: ONYOMI
      }
      readings {
        reading: "ひと"
        is_primary: false
        type: KUNYOMI
      }
      readings {
        reading: "かず"
        is_primary: false
        type: NANORI
      }
      meanings {
        meaning: "One"
        type: PRIMARY
      }
      component_subject_ids: 1
      kanji {
        meaning_mnemonic: "Lying on the <radical>ground</radical> is something that looks just like the ground, the number <kanji>One</kanji>. Why is this One lying down? It\\'s been shot by the number two. It\\'s lying there, bleeding out and dying. The number One doesn\\'t have long to live."
        meaning_hint: "To remember the meaning of <kanji>One</kanji>, imagine yourself there at the scene of the crime. You grab <kanji>One</kanji> in your arms, trying to prop it up, trying to hear its last words. Instead, it just splatters some blood on your face. \\"Who did this to you?\\" you ask. The number One points weakly, and you see number Two running off into an alleyway. He\\'s always been jealous of number One and knows he can be number one now that he\\'s taken the real number one out."
        reading_mnemonic: "As you\\'re sitting there next to <kanji>One</kanji>, holding him up, you start feeling a weird sensation all over your skin. From the wound comes a fine powder (obviously coming from the special bullet used to kill One) that causes the person it touches to get extremely <reading>itchy</reading> (いち)"
        reading_hint: "Make sure you feel the ridiculously <reading>itchy</reading> sensation covering your body. It climbs from your hands, where you\\'re holding the number <kanji>One</kanji> up, and then goes through your arms, crawls up your neck, goes down your body, and then covers everything. It becomes uncontrollable, and you\\'re scratching everywhere, writhing on the ground. It\\'s so itchy that it\\'s the most painful thing you\\'ve ever experienced (you should imagine this vividly, so you remember the reading of this kanji)."
        visually_similar_kanji: "互下両土且正本末未士丁七二十"
      }
      amalgamation_subject_ids: 56
      amalgamation_subject_ids: 88
      amalgamation_subject_ids: 91
    """)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.subjects(progress: progress)) {
      XCTAssertEqual(result.subjects.count, 1)
      XCTAssertEqual(result.subjects[0], expected)
      XCTAssertEqual(result.updatedAt, "2018-04-09T18:08:59.946969Z")
    }
    XCTAssertEqual(progress.totalUnitCount, 1)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }

  func testSubjectsUpdatedAfter() {
    var request = StubRequest(method: .GET,
                              url: URL(string: "https://api.wanikani.com/v2/subjects" +
                                "?hidden=false&updated_after=foobar")!)
    request.setHeader(key: "Authorization", value: "Token token=bob")
    request.response.body = """
    {
      "object": "collection",
      "url": "https://api.wanikani.com/v2/subjects",
      "pages": {
        "per_page": 500,
        "next_url": null,
        "previous_url": null
      },
      "total_count": 1600,
      "data_updated_at": "2017-11-29T19:37:03.571377Z",
      "data": []
    }
    """.data(using: .utf8)
    Hippolyte.shared.add(stubbedRequest: request)

    let progress = Progress(totalUnitCount: -1)
    if let result = waitForPromise(client.subjects(progress: progress, updatedAfter: "foobar")) {
      XCTAssertEqual(result.subjects.count, 0)
      XCTAssertEqual(result.updatedAt, "2017-11-29T19:37:03.571377Z")
    }
    XCTAssertEqual(progress.totalUnitCount, 4)
    XCTAssertEqual(progress.completedUnitCount, 1)
  }
}
