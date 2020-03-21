// Copyright 2020 David Sansome
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

/**
 * Client for the WaniKani v2 API.
 * You need an API token to use this class.  Use WaniKaniWebClient to get an
 * API token from a username and password.
 */
@objc(Client)
class WaniKaniAPIClient: NSObject {
  private let dataLoader: DataLoader
  private let apiToken: String
  private let session: URLSession

  @objc
  init(apiToken: String, dataLoader: DataLoader) {
    self.dataLoader = dataLoader
    self.apiToken = apiToken

    let configuration = URLSessionConfiguration.default
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    session = URLSession(configuration: configuration)

    super.init()
  }

  // MARK: - Retrieving data

  /** Fetches information about the logged-in user. */
  func user() -> Promise<TKMUser> {
    firstly {
      query(authorize(URL(string: "\(kBaseUrl)/user")!))
    }.map { (data: Response<UserData>) -> TKMUser in
      data.data.toProto()
    }
  }

  typealias Assignments = (assignments: [TKMAssignment], updatedAt: String)
  /**
   * Fetches the user's assignments.  If updatedAfter is empty, all assignments are returned,
   * otherwise returns only the ones modified after that date.
   */
  func assignments(updatedAfter: String = "") -> Promise<Assignments> {
    // Build the URL.
    var url = URLComponents(string: "\(kBaseUrl)/assignments")!
    url.queryItems = [
      URLQueryItem(name: "unlocked", value: "true"),
      URLQueryItem(name: "hidden", value: "false"),
    ]
    if !updatedAfter.isEmpty {
      url.queryItems?.append(URLQueryItem(name: "updated_after",
                                          value: updatedAfter))
    }

    // Fetch the data and convert to protobufs.
    return firstly {
      pagedQuery(url: url.url!)
    }.map { (allData: [Response<AssignmentData>]) -> Assignments in
      var ret = [TKMAssignment]()
      for data in allData {
        ret.append(data.data.toProto(id: data.id, dataLoader: self.dataLoader))
      }
      return (assignments: ret, updatedAt: allData[0].data_updated_at)
    }
  }

  typealias StudyMaterials = (studyMaterials: [TKMStudyMaterials], updatedAt: String)

  /**
   * Fetches the user's study materials.  If updatedAfter is empty, all study materials are
   * returned, otherwise returns only the ones modified after that date.
   */
  func studyMaterials(updatedAfter: String = "") -> Promise<StudyMaterials> {
    // Build the URL.
    var url = URLComponents(string: "\(kBaseUrl)/study_materials")!
    if !updatedAfter.isEmpty {
      url.queryItems?.append(URLQueryItem(name: "updated_after",
                                          value: updatedAfter))
    }

    // Fetch the data and convert to protobufs.
    return firstly {
      pagedQuery(url: url.url!)
    }.map { (allData: [Response<StudyMaterialData>]) -> StudyMaterials in
      var ret = [TKMStudyMaterials]()
      for data in allData {
        ret.append(data.data.toProto(id: data.id))
      }
      return (studyMaterials: ret, updatedAt: allData[0].data_updated_at)
    }
  }

  /**
   * Fetches one study material by Subject ID.
   */
  func studyMaterial(subjectId: Int) -> Promise<TKMStudyMaterials?> {
    // Build the URL.
    let url = URLComponents(string: "\(kBaseUrl)/study_materials?subject_ids=\(subjectId)")!

    // Fetch the data and convert to a protobuf.
    return firstly {
      pagedQuery(url: url.url!)
    }.map { (allData: [Response<StudyMaterialData>]) -> TKMStudyMaterials? in
      guard let response = allData.first else {
        return nil
      }
      return response.data.toProto(id: response.id)
    }
  }

  typealias LevelProgressions = (levels: [TKMLevel], updatedAt: String)

  func levelProgressions(updatedAfter: String = "") -> Promise<LevelProgressions> {
    // Build the URL.
    var url = URLComponents(string: "\(kBaseUrl)/level_progressions")!
    if !updatedAfter.isEmpty {
      url.queryItems?.append(URLQueryItem(name: "updated_after",
                                          value: updatedAfter))
    }

    // Fetch the data and convert to protobufs.
    return firstly {
      pagedQuery(url: url.url!)
    }.map { (allData: [Response<LevelProgressionData>]) -> LevelProgressions in
      var ret = [TKMLevel]()
      for data in allData {
        ret.append(data.data.toProto(id: data.id))
      }
      return (levels: ret, updatedAt: allData[0].data_updated_at)
    }
  }

  // MARK: - Sending lesson/review progress

  func sendProgress(_ progress: TKMProgress) -> Promise<TKMAssignment> {
    if progress.isLesson {
      return startAssignment(progress)
    }
    return createReview(progress)
  }

  private func startAssignment(_ progress: TKMProgress) -> Promise<TKMAssignment> {
    let url = URL(string: "\(kBaseUrl)/assignments/\(progress.assignment.id_p)/start")!
    let body = StartAssignmentRequest(started_at: WaniKaniDate(date: progress.createdAtDate))

    return firstly { () -> Promise<Response<AssignmentData>> in
      var request = self.authorize(url)
      try request.setJSONBody(method: "PUT", body: body)

      return query(request)
    }.map { (data: Response<AssignmentData>) -> TKMAssignment in
      data.data.toProto(id: data.id, dataLoader: self.dataLoader)
    }
  }

  private func createReview(_ progress: TKMProgress) -> Promise<TKMAssignment> {
    let url = URL(string: "\(kBaseUrl)/reviews/")!
    let body = CreateReviewRequest(review: CreateReviewRequest
      .Review(assignment_id: Int(progress.assignment!.id_p),
              incorrect_meaning_answers: progress
                .meaningWrong ? 1 : 0,
              incorrect_reading_answers: progress
                .readingWrong ? 1 : 0,
              created_at: WaniKaniDate(date: progress
                .createdAtDate)))

    return firstly { () -> Promise<MultiResourceResponse<ReviewData>> in
      var request = self.authorize(url)
      try request.setJSONBody(method: "POST", body: body)

      return query(request)
    }.map { (data: MultiResourceResponse<ReviewData>) -> TKMAssignment in
      if let assignment = data.resources_updated?.assignment {
        return assignment.data.toProto(id: assignment.id, dataLoader: self.dataLoader)
      }
      return TKMAssignment()
    }
  }

  // MARK: - Sending study material updates

  func updateStudyMaterial(_ pb: TKMStudyMaterials) -> Promise<Void> {
    firstly { () -> Promise<TKMStudyMaterials?> in
      // We need to check if a study material for the subject already exists.
      studyMaterial(subjectId: Int(pb.subjectId))
    }.then { (existing: TKMStudyMaterials?) -> DataTaskPromise in
      var synonyms = [String]()
      for synonym in pb.meaningSynonymsArray {
        synonyms.append(synonym as! String)
      }
      var body = StudyMaterialRequest(study_material: StudyMaterialRequest
        .StudyMaterial(meaning_synonyms: synonyms))

      var url: URL
      var method: String
      if let existing = existing {
        method = "PUT"
        url = URL(string: "\(kBaseUrl)/study_materials/\(existing.id_p)")!
      } else {
        method = "POST"
        url = URL(string: "\(kBaseUrl)/study_materials")!
        body.study_material.subject_id = Int(pb.subjectId)
      }

      var request = self.authorize(url)
      try request.setJSONBody(method: method, body: body)
      return self.session.dataTask(.promise, with: request)
    }.map { _ in
      // Ignore the response content.
    }
  }

  // MARK: - HTTP requests

  /** Returns an authorized URLRequest for the given URL. */
  private func authorize(_ url: URL) -> URLRequest {
    var req = URLRequest(url: url)
    req.setValue("Token token=\(apiToken)", forHTTPHeaderField: "Authorization")
    return req
  }

  /** Fetches all pages of a multi-page query and combines the results into an array. */
  private func pagedQuery<DataType: Codable>(url: URL) -> Promise<[DataType]> {
    pagedQuery(url: url, results: [])
  }

  private func pagedQuery<DataType: Codable>(url: URL, results: [DataType]) -> Promise<[DataType]> {
    firstly {
      query(authorize(url))
    }.then { (response: PaginatedResponse<[DataType]>) -> Promise<[DataType]> in
      // Add these results to the previous ones.
      var results = results
      results.append(contentsOf: response.data)

      // If there's a next page, request that.
      if let pages = response.pages, let nextURLString = pages.next_url,
        let nextURL = URL(string: nextURLString) {
        return self.pagedQuery(url: nextURL, results: results)
      }

      // Otherwise we're done - return the results.
      return .value(results)
    }
  }

  /** Fetches a single URL from the WaniKani API and returns its data. */
  private func query<Type: Codable>(_ req: URLRequest) -> Promise<Type> {
    firstly { () -> DataTaskPromise in
      NSLog("%@ %@", req.httpMethod!, req.url!.absoluteString)
      return session.dataTask(.promise, with: req)
    }.map { (data, response) -> Type in
      let response = response as! HTTPURLResponse
      switch response.statusCode {
      case 200:
        // Decode the API response.
        return try decodeJSON(data, request: req, response: response)
      case 400 ..< 500:
        // Decode an API error response.
        let err: ErrorResponse = try decodeJSON(data, request: req, response: response)
        throw WaniKaniAPIError(code: err.code, message: err.error, request: req, response: response)
      default:
        throw WaniKaniAPIError(code: response.statusCode, message: nil, request: req,
                               response: response)
      }
    }
  }
}

// MARK: - Errors

/** Error from the WaniKani API.  */
struct WaniKaniAPIError: Error {
  let code: Int
  let message: String?
  let request: URLRequest
  let response: HTTPURLResponse
}

struct WaniKaniJSONDecodeError: Error {
  let data: Data // The data that couldn't be decoded.
  let error: Error // The underlying JSON decode error.
  let request: URLRequest // The HTTP request.
  let response: HTTPURLResponse // The HTTP response.
}

private let kBaseUrl = "https://api.wanikani.com/v2"

// MARK: - JSON decoding

func decodeJSON<T: Decodable>(_ data: Data, request: URLRequest,
                              response: HTTPURLResponse) throws -> T {
  do {
    NSLog("Decoding JSON as %@: %@", String(describing: T.self),
          String(data: data, encoding: .utf8)!)
    return try JSONDecoder().decode(T.self, from: data)
  } catch {
    throw WaniKaniJSONDecodeError(data: data, error: error, request: request, response: response)
  }
}

// MARK: - Date parsing and formatting

/** Recognises all possible date formats returned from the WaniKani API. */
struct WaniKaniDate: Codable {
  /** Formats a Date to a String suitable for use in the WaniKani API. */
  static func format(date: Date) -> String {
    formatters.first!.string(from: date)
  }

  let date: Date

  /** Number of seconds since 1970. */
  var seconds: Int32 {
    Int32(date.timeIntervalSince1970)
  }

  init(date: Date) {
    self.date = date
  }

  // Implements Decodable.
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let str = try container.decode(String.self)
    for formatter in WaniKaniDate.formatters {
      if let date = formatter.date(from: str) {
        self.init(date: date)
        return
      }
    }
    throw DecodingError.dataCorruptedError(in: container,
                                           debugDescription: "Invalid date format")
  }

  static func fromString(_ str: String) -> WaniKaniDate? {
    for formatter in WaniKaniDate.formatters {
      if let date = formatter.date(from: str) {
        return WaniKaniDate(date: date)
      }
    }
    return nil
  }

  // Implements Encodable.
  func encode(to encoder: Encoder) throws {
    try WaniKaniDate.format(date: date).encode(to: encoder)
  }

  private static func makeDateFormatter(_ format: String) -> DateFormatter {
    let ret = DateFormatter()
    ret.dateFormat = format
    ret.timeZone = TimeZone(secondsFromGMT: 0)
    ret.locale = Locale(identifier: "en_US_POSIX")
    return ret
  }

  private static let formatters = [
    makeDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"),
    makeDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"),
    makeDateFormatter("yyyy-MM-dd'T'HH:mm:ss'Z'"),
    makeDateFormatter("yyyyMMdd'T'HH:mm:ss.SSSSSS'Z'"),
    makeDateFormatter("yyyyMMdd'T'HH:mm:ss.SSS'Z'"),
    makeDateFormatter("yyyyMMdd'T'HH:mm:ss'Z'"),
    makeDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSSSSX"),
    makeDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSX"),
    makeDateFormatter("yyyy-MM-dd'T'HH:mm:ssX"),
  ]
}

/** Sets a proto timestamp field to a WaniKaniDate. */
private func setProtoDate(_ pb: GPBMessage, field: String, to date: WaniKaniDate?) {
  if let date = date {
    pb.setValue(date.seconds, forKey: field)
  }
}

// MARK: - JSON API structures

/** Base container for all successful API response types. */
private class Response<DataType: Codable>: Codable {
  // Fields common to all responses.
  var id: Int?
  var data_updated_at: String
  var data: DataType
}

/** Container for paginated API responses. */
private class PaginatedResponse<DataType: Codable>: Response<DataType> {
  // Pagination information.  Present in paginated responses.
  struct Pages: Codable {
    var per_page: Int
    var next_url: String?
    var previous_url: String?
  }

  var pages: Pages?
  var total_count: Int?
}

/** Container for API responses that update multiple resources. */
private class MultiResourceResponse<DataType: Codable>: Response<DataType> {
  // Other resources that were updated by this request.  Present most notably in the create
  // review response.
  struct ResourcesUpdated: Codable {
    var assignment: Response<AssignmentData>?
    // TODO: review_statistic
  }

  var resources_updated: ResourcesUpdated?
}

/** Response type for /user. */
private struct UserData: Codable {
  var id: String
  var username: String
  var level: Int
  var profile_url: String
  var started_at: WaniKaniDate?
  var current_vacation_started_at: WaniKaniDate?

  struct Subscription: Codable {
    var active: Bool
    var type: String
    var max_level_granted: Int
    var period_ends_at: WaniKaniDate?
  }

  var subscription: Subscription

  struct Preferences: Codable {
    var default_voice_actor_id: Int?
    var lessons_autoplay_audio: Bool?
    var lessons_batch_size: Int?
    var lessons_presentation_order: String?
    var reviews_autoplay_audio: Bool?
    var reviews_display_srs_indicator: Bool?
  }

  var preferences: Preferences

  func toProto() -> TKMUser {
    let ret = TKMUser()
    ret.username = username
    ret.level = Int32(level)
    ret.profileURL = profile_url
    ret.maxLevelGrantedBySubscription = Int32(subscription.max_level_granted)
    ret.subscribed = subscription.active
    setProtoDate(ret, field: "subscriptionEndsAt", to: subscription.period_ends_at)
    setProtoDate(ret, field: "startedAt", to: started_at)
    setProtoDate(ret, field: "vacationStartedAt", to: current_vacation_started_at)
    return ret
  }
}

/** Response type for /assignments. */
private struct AssignmentData: Codable {
  var created_at: WaniKaniDate
  var subject_id: Int
  var subject_type: String
  var srs_stage: Int
  var srs_stage_name: String
  var unlocked_at: WaniKaniDate?
  var started_at: WaniKaniDate?
  var passed_at: WaniKaniDate?
  var burned_at: WaniKaniDate?
  var available_at: WaniKaniDate?
  var resurrected_at: WaniKaniDate?
  var passed: Bool

  func toProto(id: Int?, dataLoader: DataLoader) -> TKMAssignment {
    let ret = TKMAssignment()
    ret.id_p = Int32(id ?? 0)
    ret.subjectId = Int32(subject_id)
    ret.srsStage = Int32(srs_stage)
    ret.level = Int32(dataLoader.levelOf(subjectID: subject_id))
    setProtoDate(ret, field: "availableAt", to: available_at)
    setProtoDate(ret, field: "startedAt", to: started_at)
    setProtoDate(ret, field: "passedAt", to: passed_at)

    switch subject_type {
    case "radical":
      ret.subjectType = .radical
    case "kanji":
      ret.subjectType = .kanji
    case "vocabulary":
      ret.subjectType = .vocabulary
    default:
      fatalError("Unknown subject type \(subject_type)")
    }
    return ret
  }
}

/** Response type for /study_materials. */
private struct StudyMaterialData: Codable {
  var created_at: WaniKaniDate
  var subject_id: Int
  var subject_type: String
  var meaning_note: String?
  var reading_note: String?
  var meaning_synonyms: [String]?

  func toProto(id: Int?) -> TKMStudyMaterials {
    let ret = TKMStudyMaterials()
    ret.id_p = Int32(id ?? 0)
    ret.subjectId = Int32(subject_id)
    ret.subjectType = subject_type
    if let note = meaning_note {
      ret.meaningNote = note
    }
    if let note = reading_note {
      ret.readingNote = note
    }
    if let synonyms = meaning_synonyms {
      for synonym in synonyms {
        ret.meaningSynonymsArray.add(NSMutableString(string: synonym))
      }
    }
    return ret
  }
}

/** Response type for /level_progressions. */
private struct LevelProgressionData: Codable {
  var created_at: WaniKaniDate
  var level: Int
  var unlocked_at: WaniKaniDate?
  var started_at: WaniKaniDate?
  var passed_at: WaniKaniDate?
  var completed_at: WaniKaniDate?
  var abandoned_at: WaniKaniDate?

  func toProto(id: Int?) -> TKMLevel {
    let ret = TKMLevel()
    ret.id_p = Int32(id ?? 0)
    ret.level = Int32(level)
    ret.createdAt = created_at.seconds
    setProtoDate(ret, field: "abandonedAt", to: abandoned_at)
    setProtoDate(ret, field: "completedAt", to: completed_at)
    setProtoDate(ret, field: "passedAt", to: passed_at)
    setProtoDate(ret, field: "startedAt", to: started_at)
    setProtoDate(ret, field: "unlockedAt", to: unlocked_at)
    return ret
  }
}

/** Response type for /reviews. */
private struct ReviewData: Codable {
  var created_at: WaniKaniDate
  var assignment_id: Int
  var subject_id: Int
  var starting_srs_stage: Int
  var starting_srs_stage_name: String
  var ending_srs_stage: Int
  var ending_srs_stage_name: String
  var incorrect_meaning_answers: Int
  var incorrect_reading_answers: Int
}

/** Request type for PUT /assignments/<id>/start. */
private struct StartAssignmentRequest: Codable {
  var started_at: WaniKaniDate
}

/** Request type for POST /reviews. */
private struct CreateReviewRequest: Codable {
  struct Review: Codable {
    var assignment_id: Int
    var incorrect_meaning_answers: Int
    var incorrect_reading_answers: Int
    var created_at: WaniKaniDate?
  }

  var review: Review
}

/** Request type for /study_materials. */
private struct StudyMaterialRequest: Codable {
  struct StudyMaterial: Codable {
    // Only required when creating new study materials.
    var subject_id: Int?

    var meaning_note: String?
    var reading_note: String?
    var meaning_synonyms: [String]?
  }

  var study_material: StudyMaterial
}

/** Error response type. */
private struct ErrorResponse: Codable {
  var error: String?
  var code: Int
}
