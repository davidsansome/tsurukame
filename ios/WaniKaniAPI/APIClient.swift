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

/**
 * Client for the WaniKani v2 API.
 * You need an API token to use this class.  Use WaniKaniWebClient to get an
 * API token from a username and password.
 */
@objc(Client)
class WaniKaniAPIClient: NSObject {
  private let dataLoader: DataLoaderProtocol
  private let apiToken: String
  private let session: URLSession

  @objc
  init(apiToken: String, dataLoader: DataLoaderProtocol) {
    self.dataLoader = dataLoader
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
        ret.append(data.data.toProto(id: data.id, dataLoader: self.dataLoader))
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
  func studyMaterial(subjectId: Int, progress: Progress) -> Promise<TKMStudyMaterials?> {
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
      pagedQuery(url: url.url!, progress: progress)
    }.map { (allData: Response<[Response<SubjectData>]>) -> Subjects in
      var ret = [TKMSubject]()
      for data in allData.data {
        if let subject = data.data.toProto(response: data) {
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
    let url = URL(string: "\(kBaseUrl)/reviews")!
    var body = CreateReviewRequest(review: CreateReviewRequest
      .Review(assignment_id: Int(progress.assignment!.id_p),
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
        return assignment.data.toProto(id: assignment.id, dataLoader: self.dataLoader)
      }
      return TKMAssignment()
    }
  }

  // MARK: - Sending study material updates

  func updateStudyMaterial(_ pb: TKMStudyMaterials) -> Promise<Void> {
    firstly { () -> Promise<TKMStudyMaterials?> in
      // We need to check if a study material for the subject already exists.
      studyMaterial(subjectId: Int(pb.subjectId), progress: Progress(totalUnitCount: 1))
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
  init(from decoder: Decoder) throws {
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
  required init(from decoder: Decoder) throws {
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
  required init(from decoder: Decoder) throws {
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
  var subject_id: Int
  var subject_type: String
  var srs_stage: Int
  var unlocked_at: WaniKaniDate?
  var started_at: WaniKaniDate?
  var passed_at: WaniKaniDate?
  var available_at: WaniKaniDate?

  func toProto(id: Int?, dataLoader: DataLoaderProtocol) -> TKMAssignment {
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
  var ending_srs_stage: Int
  var incorrect_meaning_answers: Int
  var incorrect_reading_answers: Int
}

/** Response type for /subjects. */
private struct SubjectData: Codable {
  // Common attributes.
  var auxiliary_meanings: [AuxiliaryMeaning]?
  var characters: String?
  var created_at: WaniKaniDate
  var document_url: String
  var hidden_at: WaniKaniDate?
  var lesson_position: Int
  var level: Int
  var meanings: [Meaning]
  var slug: String
  var spaced_repetition_system_id: Int

  // Markup highlighting.
  var meaning_mnemonic: String?
  var reading_mnemonic: String?
  var meaning_hint: String?
  var reading_hint: String?

  var amalgamation_subject_ids: [Int32]? // Radical and Kanji.
  var character_images: [CharacterImage]? // Radical.
  var component_subject_ids: [Int32]? // Kanji and Vocabulary.
  var readings: [Reading]? // Kanji and Vocabulary.
  var visually_similar_subject_ids: [Int]? // Kanji.
  var context_sentences: [ContextSentence]? // Vocabulary.
  var parts_of_speech: [String]? // Vocabulary.
  var pronunciation_audios: [PronounciationAudio]? // Vocabulary.

  struct Meaning: Codable {
    var meaning: String
    var primary: Bool
    var accepted_answer: Bool
  }

  struct AuxiliaryMeaning: Codable {
    var meaning: String
    var type: String
  }

  struct Reading: Codable {
    var reading: String
    var primary: Bool
    var accepted_answer: Bool
    var type: String? // kunyomi, nanori, or onyomi
  }

  struct CharacterImage: Codable {
    var url: String
    var content_type: String
    var metadata: Metadata

    struct Metadata: Codable {
      // image/svg+xml:
      var inline_styles: Bool?

      // image/png:
      var color: String?
      var dimensions: String?
      var style_name: String?
    }
  }

  struct ContextSentence: Codable {
    var en: String
    var ja: String
  }

  struct PronounciationAudio: Codable {
    var url: String
    var content_type: String
    var metadata: Metadata

    struct Metadata: Codable {
      var gender: String?
      var source_id: Int?
      var pronounciation: String?
      var voice_actor_id: Int?
      var voice_actor_name: String?
      var voice_description: String?
    }
  }

  func toProto(response: Response<SubjectData>) -> TKMSubject? {
    let ret = TKMSubject()
    ret.id_p = Int32(response.id ?? 0)
    ret.level = Int32(level)
    ret.slug = slug
    ret.documentURL = document_url
    ret.japanese = characters
    ret.meaningsArray = convertMeanings()

    guard let objectType = response.object else {
      return nil
    }

    if objectType == "kanji" || objectType == "vocabulary" {
      ret.readingsArray = convertReadings()
      ret.componentSubjectIdsArray = convertSubjectIDArray(component_subject_ids)
    }
    if objectType == "radical" || objectType == "kanji" {
      ret.amalgamationSubjectIdsArray = convertSubjectIDArray(amalgamation_subject_ids)
    }

    switch objectType {
    case "radical":
      ret.radical = TKMRadical()
      ret.radical.mnemonic = meaning_mnemonic
      if ret.japanese.isEmpty, let url = bestCharacterImageUrl() {
        ret.radical.characterImage = url
        ret.radical.hasCharacterImageFile = true
      }

    case "kanji":
      ret.kanji = TKMKanji()
      ret.kanji.meaningMnemonic = meaning_mnemonic
      ret.kanji.meaningHint = meaning_hint
      ret.kanji.readingMnemonic = reading_mnemonic
      ret.kanji.readingHint = reading_hint

    case "vocabulary":
      ret.vocabulary = TKMVocabulary()
      ret.vocabulary.meaningExplanation = meaning_mnemonic
      ret.vocabulary.readingExplanation = reading_mnemonic
      ret.vocabulary.audioIdsArray = convertAudioIds()
      ret.vocabulary.partsOfSpeechArray = convertPartsofSpeech()
      ret.vocabulary.sentencesArray = convertContextSentences()

    default:
      NSLog("Unknown subject type: %@", objectType)
      return nil
    }

    // TODO:
    // - visually similar kanji
    // - order component subject IDs
    // - sort amalgamation subject IDs by level
    // - add deprecated radical mnemonics

    return ret
  }

  private func convertSubjectIDArray(_ array: [Int32]?) -> GPBInt32Array? {
    guard let array = array else {
      return nil
    }
    let ret = GPBInt32Array()
    for value in array {
      ret.addValue(value)
    }
    return ret
  }

  private func bestCharacterImageUrl() -> String? {
    if let character_images = character_images {
      for image in character_images {
        if image.content_type == "image/svg+xml",
          let inline_styles = image.metadata.inline_styles,
          inline_styles {
          return image.url
        }
      }
    }
    return nil
  }

  private func convertAudioIds() -> GPBInt32Array {
    let ret = GPBInt32Array()
    if let pronunciation_audios = pronunciation_audios {
      for audio in pronunciation_audios {
        if audio.content_type == "audio/mpeg",
          let dash = audio.url.firstIndex(of: "-"),
          let id = Int32(audio.url[audio.url.index(audio.url.startIndex, offsetBy: 32) ... dash]) {
          ret.addValue(id)
        }
      }
    }
    return ret
  }

  private func convertMeanings() -> NSMutableArray {
    let ret = NSMutableArray()
    for meaning in meanings {
      let pb = TKMMeaning()
      pb.meaning = meaning.meaning
      pb.type = meaning.primary ? .primary : .secondary
      ret.add(pb)
    }
    if let auxiliary_meanings = auxiliary_meanings {
      for meaning in auxiliary_meanings {
        let pb = TKMMeaning()
        pb.meaning = meaning.meaning
        switch meaning.type {
        case "blacklist":
          pb.type = .blacklist
        case "whitelist":
          pb.type = .auxiliaryWhitelist
        default:
          NSLog("Unknown auxiliary meaning type: %@", meaning.type)
          continue
        }
        ret.add(pb)
      }
    }
    return ret
  }

  private func convertReadings() -> NSMutableArray {
    let ret = NSMutableArray()
    if let readings = readings {
      for reading in readings {
        if reading.reading == "None" {
          continue
        }
        let pb = TKMReading()
        pb.reading = reading.reading
        pb.isPrimary = reading.primary
        if let type = reading.type {
          switch type {
          case "onyomi":
            pb.type = .onyomi
          case "kunyomi":
            pb.type = .kunyomi
          case "nanori":
            pb.type = .nanori
          default:
            NSLog("Unknown reading type: %@", type)
            continue
          }
        }
        ret.add(pb)
      }
    }
    return ret
  }

  private func convertPartsofSpeech() -> GPBEnumArray {
    let ret = GPBEnumArray()
    if let parts_of_speech = parts_of_speech {
      for part in parts_of_speech {
        if let enumValue = convertPartOfSpeech(part) {
          ret.addValue(enumValue.rawValue)
        }
      }
    }
    return ret
  }

  private func convertPartOfSpeech(_ part: String) -> TKMVocabulary_PartOfSpeech? {
    switch part.replacingOccurrences(of: " ", with: "_") {
    case "noun":
      return .noun
    case "numeral":
      return .numeral
    case "intransitive_verb":
      return .intransitiveVerb
    case "ichidan_verb":
      return .ichidanVerb
    case "transitive_verb":
      return .transitiveVerb
    case "no_adjective", "の_adjective":
      return .noAdjective
    case "godan_verb":
      return .godanVerb
    case "na_adjective", "な_adjective":
      return .naAdjective
    case "i_adjective", "い_adjective":
      return .iAdjective
    case "suffix":
      return .suffix
    case "adverb":
      return .adverb
    case "suru_verb", "する_verb":
      return .suruVerb
    case "prefix":
      return .prefix
    case "proper_noun":
      return .properNoun
    case "expression":
      return .expression
    case "adjective":
      return .adjective
    case "interjection":
      return .interjection
    case "counter":
      return .counter
    case "pronoun":
      return .pronoun
    case "conjunction":
      return .conjunction
    default:
      NSLog("Unknown part of speech: %@", part)
      return nil
    }
  }

  private func convertContextSentences() -> NSMutableArray {
    let ret = NSMutableArray()
    if let context_sentences = context_sentences {
      for context in context_sentences {
        let pb = TKMVocabulary_Sentence()
        pb.english = context.en
        pb.japanese = context.ja
        ret.add(pb)
      }
    }
    return ret
  }
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
