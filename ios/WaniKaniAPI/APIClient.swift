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
import SwiftProtobuf

protocol SubjectLevelGetter: AnyObject {
  func levelOf(subjectId: Int32) -> Int?
}

/**
 * Client for the WaniKani v2 API.
 * You need an API token to use this class.  Use WaniKaniWebClient to get an
 * API token from a username and password.
 */
@objc(Client)
class WaniKaniAPIClient: NSObject {
  weak var subjectLevelGetter: SubjectLevelGetter!

  private let apiToken: String
  private let session: URLSession

  @objc
  init(apiToken: String) {
    self.apiToken = apiToken

    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
    session = URLSession(configuration: sessionConfig)

    super.init()
  }

  // MARK: - Retrieving data

  /** Fetches information about the logged-in user. */
  func user(progress: Progress) -> Promise<TKMUser> {
    progress.totalUnitCount = 1
    return firstly {
      query(authorize(URL(string: "\(kBaseUrl)/user")!))
    }.ensure {
      progress.completedUnitCount = 1
    }.map { (data: Response<UserData>) -> TKMUser in
      data.data.toProto()
    }
  }

  typealias Assignments = (assignments: [TKMAssignment], updatedAt: String)
  /**
   * Fetches the user's assignments. If updatedAfter is empty, all assignments are returned,
   * otherwise returns only the ones modified after that date.
   */
  func assignments(progress: Progress, updatedAfter: String = "") -> Promise<Assignments> {
    // Build the URL.
    var url = URLComponents(string: "\(kBaseUrl)/assignments")!
    url.queryItems = [
      URLQueryItem(name: "unlocked", value: "true"),
      URLQueryItem(name: "hidden", value: "false"),
    ]
    if !updatedAfter.isEmpty {
      url.queryItems!.append(URLQueryItem(name: "updated_after",
                                          value: updatedAfter))
    }

    // Fetch the data and convert to protobufs.
    return firstly {
      pagedQuery(url: url.url!, progress: progress)
    }.map { (allData: Response<[Response<AssignmentData>]>) -> Assignments in
      var ret = [TKMAssignment]()
      for data in allData.data {
        ret.append(data.data.toProto(id: data.id, subjectLevelGetter: self.subjectLevelGetter))
      }
      return (assignments: ret, updatedAt: allData.data_updated_at ?? updatedAfter)
    }
  }

  typealias StudyMaterials = (studyMaterials: [TKMStudyMaterials], updatedAt: String)

  /**
   * Fetches the user's study materials.  If updatedAfter is empty, all study materials are
   * returned, otherwise returns only the ones modified after that date.
   */
  func studyMaterials(progress: Progress, updatedAfter: String = "") -> Promise<StudyMaterials> {
    // Build the URL.
    var url = URLComponents(string: "\(kBaseUrl)/study_materials")!
    if !updatedAfter.isEmpty {
      url.queryItems = []
      url.queryItems!.append(URLQueryItem(name: "updated_after",
                                          value: updatedAfter))
    }

    // Fetch the data and convert to protobufs.
    return firstly {
      pagedQuery(url: url.url!, progress: progress)
    }.map { (allData: Response<[Response<StudyMaterialData>]>) -> StudyMaterials in
      var ret = [TKMStudyMaterials]()
      for data in allData.data {
        ret.append(data.data.toProto(id: data.id))
      }
      return (studyMaterials: ret, updatedAt: allData.data_updated_at ?? updatedAfter)
    }
  }

  /**
   * Fetches one study material by Subject ID.
   */
  func studyMaterial(subjectId: Int32, progress: Progress) -> Promise<TKMStudyMaterials?> {
    progress.totalUnitCount = 1

    // Build the URL.
    let url = URLComponents(string: "\(kBaseUrl)/study_materials?subject_ids=\(subjectId)")!

    // Fetch the data and convert to a protobuf.
    return firstly {
      query(authorize(url.url!))
    }.ensure {
      progress.completedUnitCount = 1
    }.map { (allData: Response<[Response<StudyMaterialData>]>) -> TKMStudyMaterials? in
      guard let response = allData.data.first else {
        return nil
      }
      return response.data.toProto(id: response.id)
    }
  }

  typealias LevelProgressions = (levels: [TKMLevel], updatedAt: String)

  func levelProgressions(progress: Progress,
                         updatedAfter: String = "") -> Promise<LevelProgressions> {
    // Build the URL.
    var url = URLComponents(string: "\(kBaseUrl)/level_progressions")!
    if !updatedAfter.isEmpty {
      url.queryItems = []
      url.queryItems!.append(URLQueryItem(name: "updated_after",
                                          value: updatedAfter))
    }

    // Fetch the data and convert to protobufs.
    return firstly {
      pagedQuery(url: url.url!, progress: progress)
    }.map { (allData: Response<[Response<LevelProgressionData>]>) -> LevelProgressions in
      var ret = [TKMLevel]()
      for data in allData.data {
        ret.append(data.data.toProto(id: data.id))
      }
      return (levels: ret, updatedAt: allData.data_updated_at ?? updatedAfter)
    }
  }

  typealias Subjects = (subjects: [TKMSubject], updatedAt: String)
  /**
   * Fetches all subjects. If updatedAfter is empty, all subjects are returned, otherwise returns
   * only the ones modified after that date.
   */
  func subjects(progress: Progress,
                updatedAfter: String = "") -> Promise<Subjects> {
    // Build the URL.
    var url = URLComponents(string: "\(kBaseUrl)/subjects")!
    url.queryItems = [
      URLQueryItem(name: "hidden", value: "false"),
    ]
    if !updatedAfter.isEmpty {
      url.queryItems!.append(URLQueryItem(name: "updated_after",
                                          value: updatedAfter))
    }

    // Fetch the data and convert to protobufs.
    return firstly {
      updatedAfter.isEmpty ?
        speculativeParallelPagedQuery(url: url.url!, progress: progress, perPage: 1000,
                                      numPages: 9) :
        pagedQuery(url: url.url!, progress: progress)
    }.map { (allData: Response<[Response<SubjectData>]>) -> Subjects in
      var ret = [TKMSubject]()
      var seenIds = Set<Int32>()
      for data in allData.data {
        guard let id = data.id else {
          continue
        }
        if seenIds.contains(id) {
          continue
        }
        seenIds.insert(id)

        if let objectType = data.object,
          let subject = data.data.toProto(id: id, objectType: objectType) {
          ret.append(subject)
        }
      }
      return (subjects: ret, updatedAt: allData.data_updated_at ?? updatedAfter)
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
    let url = URL(string: "\(kBaseUrl)/assignments/\(progress.assignment.id)/start")!
    let body = StartAssignmentRequest(started_at: WaniKaniDate(date: progress.createdAtDate))

    return firstly { () -> Promise<Response<AssignmentData>> in
      var request = self.authorize(url)
      try request.setJSONBody(method: "PUT", body: body)

      return query(request)
    }.map { (data: Response<AssignmentData>) -> TKMAssignment in
      data.data.toProto(id: data.id, subjectLevelGetter: self.subjectLevelGetter)
    }
  }

  private func createReview(_ progress: TKMProgress) -> Promise<TKMAssignment> {
    let url = URL(string: "\(kBaseUrl)/reviews")!
    var body = CreateReviewRequest(review: CreateReviewRequest
      .Review(assignment_id: progress.assignment.id,
              incorrect_meaning_answers: Int(progress.meaningWrongCount),
              incorrect_reading_answers: Int(progress.readingWrongCount)))

    // Don't set created_at if it's very recent to try to allow for some clock drift.
    if progress.hasCreatedAt, progress.createdAtDate.timeIntervalSinceNow < -900 {
      body.review.created_at = WaniKaniDate(date: progress.createdAtDate)
    }

    return firstly { () -> Promise<MultiResourceResponse<ReviewData>> in
      var request = self.authorize(url)
      try request.setJSONBody(method: "POST", body: body)

      return query(request)
    }.map { (data: MultiResourceResponse<ReviewData>) -> TKMAssignment in
      if let assignment = data.resources_updated?.assignment {
        return assignment.data.toProto(id: assignment.id,
                                       subjectLevelGetter: self.subjectLevelGetter)
      }
      return TKMAssignment()
    }
  }

  // MARK: - Sending study material updates

  func updateStudyMaterial(_ pb: TKMStudyMaterials) -> Promise<Void> {
    firstly { () -> Promise<TKMStudyMaterials?> in
      // We need to check if a study material for the subject already exists.
      studyMaterial(subjectId: pb.subjectID, progress: Progress(totalUnitCount: 1))
    }.then { (existing: TKMStudyMaterials?) -> DataTaskPromise in
      var synonyms = [String]()
      for synonym in pb.meaningSynonyms {
        synonyms.append(synonym)
      }
      var body = StudyMaterialRequest(study_material: StudyMaterialRequest
        .StudyMaterial(meaning_synonyms: synonyms))

      var url: URL
      var method: String
      if let existing = existing {
        method = "PUT"
        url = URL(string: "\(kBaseUrl)/study_materials/\(existing.id)")!
      } else {
        method = "POST"
        url = URL(string: "\(kBaseUrl)/study_materials")!
        body.study_material.subject_id = pb.subjectID
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
  private func pagedQuery<DataType: Codable>(url: URL,
                                             progress: Progress) -> Promise<Response<[DataType]>> {
    let results = try! JSONDecoder()
      .decode(Response<[DataType]>.self, from: kEmptyPaginatedResultJson)
    return pagedQuery(url: url, results: results, progress: progress)
  }

  private func pagedQuery<DataType: Codable>(url: URL,
                                             results: Response<[DataType]>,
                                             progress: Progress)
    -> Promise<Response<[DataType]>> {
    firstly {
      query(authorize(url))
    }.then { (response: PaginatedResponse<[DataType]>) -> Promise<Response<[DataType]>> in
      // Set the total progress unit count if this was the first page.
      if progress.totalUnitCount == -1,
        let totalCount = response.total_count,
        let perPage = response.pages?.per_page {
        progress.totalUnitCount = max(1, Int64(ceil(Double(totalCount) / Double(perPage))))
        progress.completedUnitCount = 1
      } else {
        progress.completedUnitCount += 1
      }

      // Add these results to the previous ones.
      results.data_updated_at = response.data_updated_at
      results.data.append(contentsOf: response.data)

      // If there's a next page, request that.
      if let pages = response.pages, let nextURLString = pages.next_url,
        let nextURL = URL(string: nextURLString) {
        return self.pagedQuery(url: nextURL, results: results, progress: progress)
      }

      // Otherwise we're done - return the results.
      return .value(results)
    }
  }

  private func speculativeParallelPagedQuery<DataType: Codable>(url: URL,
                                                                progress: Progress,
                                                                perPage: Int,
                                                                numPages: Int)
    -> Promise<Response<[DataType]>> {
    let results = try! JSONDecoder()
      .decode(Response<[DataType]>.self, from: kEmptyPaginatedResultJson)
    return speculativeParallelPagedQuery(url: url, results: results, progress: progress,
                                         perPage: perPage, numPages: numPages)
  }

  /**
   * Speculatively fetches numPages in parallel from the given base URL (without any page_after_id
   * parameter).
   *
   * If there are any more pages after the last one they will be fetched serially.
   * The results array may contain duplicate items - it's the caller's responsibility to remove
   * duplicates.
   */
  private func speculativeParallelPagedQuery<DataType: Codable>(url: URL,
                                                                results: Response<[DataType]>,
                                                                progress: Progress,
                                                                perPage: Int,
                                                                numPages: Int)
    -> Promise<Response<[DataType]>> {
    progress.totalUnitCount = 1

    var promises = [Promise<Void>]()
    for page in 0 ..< numPages {
      let pageAfterId = page * perPage - 1
      let isLastPage = page == numPages - 1

      // Construct the new page URL.
      var pageUrl = URLComponents(url: url, resolvingAgainstBaseURL: true)!
      if pageUrl.queryItems == nil {
        pageUrl.queryItems = []
      }
      pageUrl.queryItems!.append(URLQueryItem(name: "page_after_id", value: String(pageAfterId)))

      if !isLastPage {
        // Fetch the first N-1 pages as one-off queries for individual URLs.
        promises.append(firstly {
          query(authorize(pageUrl.url!))
        }.map { (response: PaginatedResponse<[DataType]>) -> Void in
          // Add these results to the previous ones.
          results.data_updated_at = response.data_updated_at
          results.data.append(contentsOf: response.data)
          return ()
        })
      } else {
        // Even though we think this is the last page it might have more pages after it, so fall
        // back to the serial page fetching behaviour.
        promises.append(firstly {
          pagedQuery(url: pageUrl.url!, results: results, progress: Progress(totalUnitCount: -1))
        }.asVoid())
      }
    }

    // Wait for all page fetches to complete.
    return when(fulfilled: promises).ensure {
      progress.completedUnitCount = 1
    }.map {
      results
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
      case 200, 201:
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

  init?(fromString str: String) {
    for formatter in WaniKaniDate.formatters {
      if let date = formatter.date(from: str) {
        self.init(date: date)
        return
      }
    }
    return nil
  }

  // Implements Decodable.
  init(from decoder: Swift.Decoder) throws {
    let container = try decoder.singleValueContainer()
    let str = try container.decode(String.self)
    if let date = WaniKaniDate(fromString: str) {
      self = date
    } else {
      throw DecodingError.dataCorruptedError(in: container,
                                             debugDescription: "Invalid date format")
    }
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
private func toProtoDate(_ date: WaniKaniDate?, setter: (Int32) -> Void) {
  if let date = date {
    setter(date.seconds)
  }
}

// MARK: - JSON API structures

/** Base container for all successful API response types. */
private class Response<DataType: Codable>: Codable {
  // Fields common to all responses.
  var id: Int32?
  var data_updated_at: String?
  var data: DataType
  var object: String?
}

/** Container for paginated API responses. */
private class PaginatedResponse<DataType: Codable>: Response<DataType> {
  // Pagination information. Present in paginated responses.
  struct Pages: Codable {
    var per_page: Int?
    var next_url: String?
  }

  var pages: Pages?
  var total_count: Int?

  private enum CodingKeys: String, CodingKey {
    case pages
    case total_count
  }

  // A custom decoder function is needed here as by default only the base class' fields are decoded.
  required init(from decoder: Swift.Decoder) throws {
    try super.init(from: decoder)
    let values = try decoder.container(keyedBy: CodingKeys.self)
    pages = try values.decodeIfPresent(Pages.self, forKey: .pages)
    total_count = try values.decodeIfPresent(Int.self, forKey: .total_count)
  }
}

private let kEmptyPaginatedResultJson = """
{
  "data_updated_at": "",
  "data": []
}
""".data(using: .utf8)!

/** Container for API responses that update multiple resources. */
private class MultiResourceResponse<DataType: Codable>: Response<DataType> {
  // Other resources that were updated by this request. Present in the create review response.
  struct ResourcesUpdated: Codable {
    var assignment: Response<AssignmentData>?
    // TODO: review_statistic
  }

  var resources_updated: ResourcesUpdated?

  private enum CodingKeys: String, CodingKey {
    case resources_updated
  }

  // A custom decoder function is needed here as by default only the base class' fields are decoded.
  required init(from decoder: Swift.Decoder) throws {
    try super.init(from: decoder)
    let values = try decoder.container(keyedBy: CodingKeys.self)
    resources_updated = try values.decodeIfPresent(ResourcesUpdated.self,
                                                   forKey: .resources_updated)
  }
}

/** Response type for /user. */
private struct UserData: Codable {
  var username: String
  var level: Int
  var profile_url: String
  var started_at: WaniKaniDate?
  var current_vacation_started_at: WaniKaniDate?

  struct Subscription: Codable {
    var active: Bool
    var max_level_granted: Int
    var period_ends_at: WaniKaniDate?
  }

  var subscription: Subscription

  func toProto() -> TKMUser {
    var ret = TKMUser()
    ret.username = username
    ret.level = Int32(level)
    ret.profileURL = profile_url
    ret.maxLevelGrantedBySubscription = Int32(subscription.max_level_granted)
    ret.subscribed = subscription.active
    toProtoDate(subscription.period_ends_at) { ret.subscriptionEndsAt = $0 }
    toProtoDate(started_at) { ret.startedAt = $0 }
    toProtoDate(current_vacation_started_at) { ret.vacationStartedAt = $0 }
    return ret
  }
}

/** Response type for /assignments. */
private struct AssignmentData: Codable {
  var subject_id: Int
  var subject_type: String
  var srs_stage: Int
  var unlocked_at: WaniKaniDate?
  var started_at: WaniKaniDate?
  var passed_at: WaniKaniDate?
  var available_at: WaniKaniDate?

  func toProto(id: Int32?, subjectLevelGetter: SubjectLevelGetter) -> TKMAssignment {
    var ret = TKMAssignment()
    ret.id = id ?? 0
    ret.subjectID = Int32(subject_id)
    ret.srsStageNumber = Int32(srs_stage)
    ret.level = Int32(subjectLevelGetter.levelOf(subjectId: ret.subjectID) ?? 0)
    toProtoDate(available_at) { ret.availableAt = $0 }
    toProtoDate(started_at) { ret.startedAt = $0 }
    toProtoDate(passed_at) { ret.passedAt = $0 }

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
  var subject_id: Int32
  var subject_type: String
  var meaning_note: String?
  var reading_note: String?
  var meaning_synonyms: [String]?

  func toProto(id: Int32?) -> TKMStudyMaterials {
    var ret = TKMStudyMaterials()
    ret.id = Int32(id ?? 0)
    ret.subjectID = Int32(subject_id)
    if let note = meaning_note {
      ret.meaningNote = note
    }
    if let note = reading_note {
      ret.readingNote = note
    }
    if let meaning_synonyms = meaning_synonyms {
      ret.meaningSynonyms = meaning_synonyms
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

  func toProto(id: Int32?) -> TKMLevel {
    var ret = TKMLevel()
    ret.id = Int32(id ?? 0)
    ret.level = Int32(level)
    ret.createdAt = created_at.seconds
    toProtoDate(abandoned_at) { ret.abandonedAt = $0 }
    toProtoDate(completed_at) { ret.completedAt = $0 }
    toProtoDate(passed_at) { ret.passedAt = $0 }
    toProtoDate(started_at) { ret.startedAt = $0 }
    toProtoDate(unlocked_at) { ret.unlockedAt = $0 }
    return ret
  }
}

/** Response type for /reviews. */
private struct ReviewData: Codable {
  var created_at: WaniKaniDate
  var assignment_id: Int
  var subject_id: Int32
  var starting_srs_stage: Int
  var ending_srs_stage: Int
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
    var assignment_id: Int32
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
    var subject_id: Int32?

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
