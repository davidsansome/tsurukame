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

private let kSectionHeaderHeight: CGFloat = 38.0
private let kSectionFooterHeight: CGFloat = 0.0
private let kFontSize: CGFloat = 14.0

private let kVisuallySimilarKanjiScoreThreshold = 400

private let kMeaningSynonymColor = UIColor(red: 0.231, green: 0.6, blue: 0.988, alpha: 1)
private let kFont = TKMStyle.japaneseFont(size: kFontSize)

private func join(_ arr: [NSAttributedString], with joinString: String) -> NSAttributedString {
  let ret = NSMutableAttributedString()
  let count = arr.count
  for i in 0 ..< count {
    ret.append(arr[i])
    if i != count - 1 {
      ret.append(attrString(joinString))
    }
  }
  return ret
}

private func renderMeanings(subject: TKMSubject,
                            studyMaterials: TKMStudyMaterials?) -> NSAttributedString {
  var strings = [NSAttributedString]()
  for meaning in subject.meaningsArray as! [TKMMeaning] {
    if meaning.type == .primary {
      strings.append(attrString(meaning.meaning))
    }
  }
  if let studyMaterials = studyMaterials {
    for meaning in studyMaterials.meaningSynonymsArray as! [String] {
      strings.append(attrString(meaning, attrs: [.foregroundColor: kMeaningSynonymColor]))
    }
  }
  for meaning in subject.meaningsArray as! [TKMMeaning] {
    if meaning.type != .primary, meaning.type != .blacklist,
      meaning.type != .auxiliaryWhitelist || !subject.hasRadical || Settings.showOldMnemonic {
      let font = UIFont.systemFont(ofSize: kFontSize, weight: .light)
      strings.append(attrString(meaning.meaning, attrs: [.font: font]))
    }
  }
  return join(strings, with: ", ")
}

private func renderReadings(readings: [TKMReading], primaryOnly: Bool) -> NSAttributedString {
  var strings = [NSAttributedString]()
  for reading in readings {
    if reading.isPrimary {
      var font = TKMStyle.japaneseFontLight(size: kFontSize)
      if !primaryOnly, readings.count > 1 {
        font = TKMStyle.japaneseFontBold(size: kFontSize)
      }
      strings.append(attrString(reading.displayText, attrs: [.font: font]))
    }
  }
  if !primaryOnly {
    let font = TKMStyle.japaneseFontLight(size: kFontSize)
    for reading in readings {
      if !reading.isPrimary {
        strings.append(attrString(reading.displayText, attrs: [.font: font]))
      }
    }
  }
  return join(strings, with: ", ")
}

private func renderNotes(studyMaterials: TKMStudyMaterials?,
                         isMeaning: Bool) -> NSAttributedString? {
  let font = UIFont.systemFont(ofSize: kFontSize, weight: .regular)
  if let studyMaterials = studyMaterials {
    if isMeaning, studyMaterials.hasMeaningNote {
      return attrString(studyMaterials.meaningNote, attrs: [.font: font])
    } else if !isMeaning, studyMaterials.hasReadingNote {
      return attrString(studyMaterials.readingNote, attrs: [.font: font])
    }
  }
  return nil
}

private func attrString(_ string: String,
                        attrs: [NSAttributedString.Key: Any]? = nil) -> NSAttributedString {
  let combinedAttrs = defaultStringAttrs().merging(attrs ?? [:]) { _, new in new }
  return NSAttributedString(string: string, attributes: combinedAttrs)
}

private func defaultStringAttrs() -> [NSAttributedString.Key: Any] {
  [.foregroundColor: TKMStyle.Color.label,
   .backgroundColor: TKMStyle.Color.cellBackground]
}

private func dateFormatter(dateStyle: DateFormatter.Style,
                           timeStyle: DateFormatter.Style) -> DateFormatter {
  let ret = DateFormatter()
  ret.dateStyle = dateStyle
  ret.timeStyle = timeStyle
  return ret
}

@objc(TKMSubjectDetailsView)
class SubjectDetailsView: UITableView, TKMSubjectChipDelegate {
  private let statsDateFormatter = dateFormatter(dateStyle: .medium, timeStyle: .medium)

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    sectionHeaderHeight = kSectionHeaderHeight
    estimatedSectionHeaderHeight = kSectionHeaderHeight
    sectionFooterHeight = kSectionFooterHeight
    estimatedSectionFooterHeight = kSectionFooterHeight
  }

  private var services: TKMServices!
  private weak var subjectDelegate: TKMSubjectDelegate!

  private var readingItem: ReadingModelItem?
  private var tableModel: TKMTableModel?
  private var lastSubjectChipTapped: TKMSubjectChip?

  @objc public func setup(withServices services: TKMServices, delegate: TKMSubjectDelegate) {
    self.services = services
    subjectDelegate = delegate
  }

  private func addMeanings(_ subject: TKMSubject,
                           studyMaterials: TKMStudyMaterials?,
                           toModel model: TKMMutableTableModel) {
    let text = renderMeanings(subject: subject, studyMaterials: studyMaterials)
      .withFontSize(kFontSize)
    let item = AttributedModelItem(text: text)

    model.addSection("Meaning")
    model.add(item)

    if let notesText = renderNotes(studyMaterials: studyMaterials, isMeaning: true) {
      let notesItem = AttributedModelItem(text: notesText.withFontSize(kFontSize))
      model.addSection("Meaning Note")
      model.add(notesItem)
    }
  }

  private func addReadings(_ subject: TKMSubject,
                           studyMaterials: TKMStudyMaterials?,
                           toModel model: TKMMutableTableModel) {
    let primaryOnly = subject.hasKanji && !Settings.showAllReadings

    let text = renderReadings(readings: subject.readingsArray as! [TKMReading],
                              primaryOnly: primaryOnly).withFontSize(kFontSize)
    let item = ReadingModelItem(text: text)
    if subject.hasVocabulary, subject.vocabulary.audioIdsArray_Count > 0 {
      item.setAudio(services.audio, subjectID: subject.id_p)
    }

    readingItem = item
    model.addSection("Reading")
    model.add(item)

    if let notesText = renderNotes(studyMaterials: studyMaterials, isMeaning: false) {
      let notesItem = AttributedModelItem(text: notesText.withFontSize(kFontSize))
      model.addSection("Reading Note")
      model.add(notesItem)
    }
  }

  private func addComponents(_ subject: TKMSubject,
                             title: String,
                             toModel model: TKMMutableTableModel) {
    let item = TKMSubjectCollectionModelItem(subjects: subject.componentSubjectIdsArray,
                                             dataLoader: services.dataLoader, delegate: self)

    model.addSection(title)
    model.add(item)
  }

  private func addSimilarKanji(_ subject: TKMSubject, toModel model: TKMMutableTableModel) {
    let currentLevel = services.localCachingClient!.getUserInfo()!.level
    var addedSection = false
    for similar in subject.kanji.visuallySimilarKanjiArray as! [TKMVisuallySimilarKanji] {
      if similar.score < kVisuallySimilarKanjiScoreThreshold {
        continue
      }
      guard let subject = services.dataLoader.load(subjectID: Int(similar.id_p)) else {
        continue
      }
      if subject.level > currentLevel {
        continue
      }
      if !addedSection {
        model.addSection("Visually Similar Kanji")
        addedSection = true
      }

      let item = TKMSubjectModelItem(subject: subject, delegate: subjectDelegate)
      model.add(item)
    }
  }

  private func addAmalgamationSubjects(_ subject: TKMSubject, toModel model: TKMMutableTableModel) {
    var subjects = [TKMSubject]()
    for i in 0 ..< subject.amalgamationSubjectIdsArray_Count {
      let subjectID = subject.amalgamationSubjectIdsArray.value(at: i)
      if let subject = services.dataLoader.load(subjectID: Int(subjectID)) {
        subjects.append(subject)
      }
    }

    if subjects.isEmpty {
      return
    }

    model.addSection("Used in")
    for subject in subjects {
      model.add(TKMSubjectModelItem(subject: subject, delegate: subjectDelegate))
    }
  }

  private func addFormattedText(_ text: [TKMFormattedText],
                                isHint: Bool,
                                toModel model: TKMMutableTableModel) {
    if text.isEmpty {
      return
    }

    var attributes = defaultStringAttrs()
    if isHint {
      attributes[.foregroundColor] = TKMStyle.Color.grey33
    }

    let formattedText = TKMRenderFormattedText(text, attributes).replaceFontSize(kFontSize)
    model.add(AttributedModelItem(text: formattedText))
  }

  private func addContextSentences(_ subject: TKMSubject, toModel model: TKMMutableTableModel) {
    if subject.vocabulary.sentencesArray_Count == 0 {
      return
    }

    model.addSection("Context Sentences")
    for sentence in subject.vocabulary.sentencesArray as! [TKMVocabulary_Sentence] {
      model.add(ContextSentenceModelItem(sentence, highlightSubject: subject,
                                         defaultAttributes: defaultStringAttrs(),
                                         fontSize: kFontSize))
    }
  }

  private func addPartsOfSpeech(_ vocab: TKMVocabulary, toModel model: TKMMutableTableModel) {
    let text = vocab.commaSeparatedPartsOfSpeech
    if text.isEmpty {
      return
    }

    model.addSection("Part of Speech")
    let item = TKMBasicModelItem(style: .default, title: text, subtitle: nil)
    item.titleFont = UIFont.systemFont(ofSize: kFontSize)
    model.add(item)
  }

  @objc public func update(withSubject subject: TKMSubject, studyMaterials: TKMStudyMaterials?,
                           assignment: TKMAssignment?) {
    let model = TKMMutableTableModel(tableView: self)
    readingItem = nil

    if subject.hasRadical {
      addMeanings(subject, studyMaterials: studyMaterials, toModel: model)

      model.addSection("Mnemonic")
      addFormattedText(subject.radical.formattedMnemonicArray as! [TKMFormattedText], isHint: false,
                       toModel: model)

      if Settings.showOldMnemonic, subject.radical!.formattedDeprecatedMnemonicArray_Count != 0 {
        model.addSection("Old Mnemonic")
        addFormattedText(subject.radical.formattedDeprecatedMnemonicArray as! [TKMFormattedText],
                         isHint: false, toModel: model)
      }

      addAmalgamationSubjects(subject, toModel: model)
    }
    if subject.hasKanji {
      addMeanings(subject, studyMaterials: studyMaterials, toModel: model)
      addReadings(subject, studyMaterials: studyMaterials, toModel: model)
      addComponents(subject, title: "Radicals", toModel: model)

      model.addSection("Meaning Explanation")
      addFormattedText(subject.kanji.formattedMeaningMnemonicArray as! [TKMFormattedText],
                       isHint: false, toModel: model)
      addFormattedText(subject.kanji.formattedMeaningHintArray as! [TKMFormattedText], isHint: true,
                       toModel: model)

      model.addSection("Reading Explanation")
      addFormattedText(subject.kanji.formattedReadingMnemonicArray as! [TKMFormattedText],
                       isHint: false, toModel: model)
      addFormattedText(subject.kanji.formattedReadingHintArray as! [TKMFormattedText], isHint: true,
                       toModel: model)

      addSimilarKanji(subject, toModel: model)
      addAmalgamationSubjects(subject, toModel: model)
    }
    if subject.hasVocabulary {
      addMeanings(subject, studyMaterials: studyMaterials, toModel: model)
      addReadings(subject, studyMaterials: studyMaterials, toModel: model)
      addComponents(subject, title: "Kanji", toModel: model)

      model.addSection("Meaning Explanation")
      addFormattedText(subject.vocabulary.formattedMeaningExplanationArray as! [TKMFormattedText],
                       isHint: false, toModel: model)

      model.addSection("Reading Explanation")
      addFormattedText(subject.vocabulary.formattedReadingExplanationArray as! [TKMFormattedText],
                       isHint: false, toModel: model)

      addPartsOfSpeech(subject.vocabulary, toModel: model)
      addContextSentences(subject, toModel: model)
    }

    // Your progress, SRS level, next review, first started, reached guru
    if let subjectAssignment = assignment {
      if subjectAssignment.hasStartedAt {
        model.addSection("Stats")
        var statString = "First started at: " + statsDateFormatter
          .string(from: subjectAssignment.startedAtDate)
        if subjectAssignment.hasSrsStage {
          statString += "\nSRS stage: " + TKMDetailedSRSStageName(subjectAssignment.srsStage)
        }
        if subjectAssignment.hasAvailableAt {
          statString += "\nNext review at: " + statsDateFormatter
            .string(from: subjectAssignment.availableAtDate)
        }
        if subjectAssignment.hasPassedAt {
          statString += "\nGurued at: " + statsDateFormatter
            .string(from: subjectAssignment.passedAtDate)
        }
        let font = UIFont.systemFont(ofSize: kFontSize, weight: .regular)
        model.add(AttributedModelItem(text: attrString(statString, attrs: [.font: font])))

        if subjectAssignment.hasSrsStage,
          TKMDetailedSRSStageName(subjectAssignment.srsStage) == "Burned" {
          // TODO: Add resurrect button
        }
      }
    }

    tableModel = model
    model.reloadTable()
  }

  @objc public func deselectLastSubjectChipTapped() {
    lastSubjectChipTapped?.backgroundColor = nil
  }

  @objc public func playAudio() {
    readingItem?.playAudio()
  }

  // MARK: - TKMSubjectChipDelegate

  func didTap(_ chip: TKMSubjectChip) {
    lastSubjectChipTapped = chip

    chip.backgroundColor = TKMStyle.Color.grey80
    subjectDelegate.didTap(chip.subject)
  }
}
