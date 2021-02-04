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

private func jsonFromBundle<T>(_ fileName: String) -> T {
  let path = Bundle.main.path(forResource: fileName, ofType: nil)
  let data = try! Data(contentsOf: URL(fileURLWithPath: path!))
  return try! JSONSerialization.jsonObject(with: data, options: []) as! T
}

private let kDeprecatedMnemonics: [Int32: String] = {
  let data: [String: String] = jsonFromBundle("old-mnemonics.json")

  var ret = [Int32: String]()
  for (id, text) in data {
    ret[Int32(id)!] = text
  }
  return ret
}()

private let kVisuallySimilarKanji: [String: String] = jsonFromBundle("visually-similar-kanji.json")

/** Response type for /subjects. */
struct SubjectData: Codable {
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

  func toProto(id: Int32, objectType: String) -> TKMSubject? {
    var ret = TKMSubject()
    ret.id = id
    ret.level = Int32(level)
    ret.slug = slug
    ret.documentURL = document_url
    if let characters = characters {
      ret.japanese = characters
    }
    ret.meanings = convertMeanings()

    if objectType == "kanji" || objectType == "vocabulary" {
      ret.readings = convertReadings()
      if let component_subject_ids = component_subject_ids {
        ret.componentSubjectIds = component_subject_ids
      }
    }
    if objectType == "radical" || objectType == "kanji" {
      if let amalgamation_subject_ids = amalgamation_subject_ids {
        ret.amalgamationSubjectIds = amalgamation_subject_ids
      }
    }

    switch objectType {
    case "radical":
      ret.radical = TKMRadical()
      if let meaning_mnemonic = meaning_mnemonic {
        ret.radical.mnemonic = meaning_mnemonic
      }
      if ret.japanese.isEmpty, let url = bestCharacterImageUrl() {
        ret.radical.characterImage = url
        ret.radical.hasCharacterImageFile_p = true
      }

      if let deprecatedMnemonic = kDeprecatedMnemonics[id] {
        ret.radical.deprecatedMnemonic = deprecatedMnemonic
      }

    case "kanji":
      ret.kanji = TKMKanji()
      if let meaning_mnemonic = meaning_mnemonic {
        ret.kanji.meaningMnemonic = meaning_mnemonic
      }
      if let meaning_hint = meaning_hint {
        ret.kanji.meaningHint = meaning_hint
      }
      if let reading_mnemonic = reading_mnemonic {
        ret.kanji.readingMnemonic = reading_mnemonic
      }
      if let reading_hint = reading_hint {
        ret.kanji.readingHint = reading_hint
      }
      if let visuallySimilarKanji = kVisuallySimilarKanji[ret.japanese] {
        ret.kanji.visuallySimilarKanji = visuallySimilarKanji
      }

    case "vocabulary":
      ret.vocabulary = TKMVocabulary()
      if let meaning_mnemonic = meaning_mnemonic {
        ret.vocabulary.meaningExplanation = meaning_mnemonic
      }
      if let reading_mnemonic = reading_mnemonic {
        ret.vocabulary.readingExplanation = reading_mnemonic
      }
      ret.vocabulary.audioIds = convertAudioIds()
      ret.vocabulary.partsOfSpeech = convertPartsofSpeech()
      ret.vocabulary.sentences = convertContextSentences()

    default:
      NSLog("Unknown subject type: %@", objectType)
      return nil
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

  private func convertAudioIds() -> [Int32] {
    var ret = [Int32]()
    if let pronunciation_audios = pronunciation_audios {
      for audio in pronunciation_audios {
        if audio.content_type == "audio/mpeg",
          let dash = audio.url.firstIndex(of: "-"),
          let id = Int32(audio.url[audio.url.index(audio.url.startIndex, offsetBy: 32) ..< dash]) {
          ret.append(id)
        }
      }
    }
    return ret
  }

  private func convertMeanings() -> [TKMMeaning] {
    var ret = [TKMMeaning]()
    for meaning in meanings {
      var pb = TKMMeaning()
      pb.meaning = meaning.meaning
      pb.type = meaning.primary ? .primary : .secondary
      ret.append(pb)
    }
    if let auxiliary_meanings = auxiliary_meanings {
      for meaning in auxiliary_meanings {
        var pb = TKMMeaning()
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
        ret.append(pb)
      }
    }
    return ret
  }

  private func convertReadings() -> [TKMReading] {
    var ret = [TKMReading]()
    if let readings = readings {
      for reading in readings {
        if reading.reading == "None" {
          continue
        }
        var pb = TKMReading()
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
        ret.append(pb)
      }
    }
    return ret
  }

  private func convertPartsofSpeech() -> [TKMVocabulary.PartOfSpeech] {
    var ret = [TKMVocabulary.PartOfSpeech]()
    if let parts_of_speech = parts_of_speech {
      for part in parts_of_speech {
        if let enumValue = convertPartOfSpeech(part) {
          ret.append(enumValue)
        }
      }
    }
    return ret
  }

  private func convertPartOfSpeech(_ part: String) -> TKMVocabulary.PartOfSpeech? {
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

  private func convertContextSentences() -> [TKMVocabulary.Sentence] {
    var ret = [TKMVocabulary.Sentence]()
    if let context_sentences = context_sentences {
      for context in context_sentences {
        var pb = TKMVocabulary.Sentence()
        pb.english = context.en
        pb.japanese = context.ja
        ret.append(pb)
      }
    }
    return ret
  }
}
