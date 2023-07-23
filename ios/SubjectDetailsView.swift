// Copyright 2023 David Sansome
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
import WaniKaniAPI

private let kSectionHeaderHeight: CGFloat = 38.0
private let kSectionFooterHeight: CGFloat = 0.0

private let kFontSize: CGFloat = {
  let bodyFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
  return bodyFontDescriptor.pointSize
}()

private let kMeaningSynonymColor = UIColor(red: 0.231, green: 0.6, blue: 0.988, alpha: 1)

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
  for meaning in subject.meanings {
    if meaning.type == .primary {
      strings.append(attrString(meaning.meaning))
    }
  }
  if let studyMaterials = studyMaterials {
    for meaning in studyMaterials.meaningSynonyms {
      strings.append(attrString(meaning, attrs: [.foregroundColor: kMeaningSynonymColor]))
    }
  }
  for meaning in subject.meanings {
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
      var font = UIFont(name: TKMStyle.japaneseFontName, size: kFontSize)
      if !primaryOnly, readings.count > 1 {
        font = UIFont(name: TKMStyle.japaneseFontNameBold, size: kFontSize)
      }
      strings
        .append(attrString(reading.displayText(useKatakanaForOnyomi: Settings.useKatakanaForOnyomi),
                           attrs: [.font: font]))
    }
  }
  if !primaryOnly {
    let font = UIFont(name: TKMStyle.japaneseFontName, size: kFontSize)
    for reading in readings {
      if !reading.isPrimary {
        strings
          .append(attrString(reading
              .displayText(useKatakanaForOnyomi: Settings.useKatakanaForOnyomi),
            attrs: [.font: font]))
      }
    }
  }
  return join(strings, with: ", ")
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

class SubjectDetailsView: UITableView, SubjectChipDelegate {
  private let statsDateFormatter = dateFormatter(dateStyle: .medium, timeStyle: .short)

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    sectionHeaderHeight = kSectionHeaderHeight
    estimatedSectionHeaderHeight = kSectionHeaderHeight
    sectionFooterHeight = kSectionFooterHeight
    estimatedSectionFooterHeight = kSectionFooterHeight
  }

  private var services: TKMServices!
  private weak var subjectDelegate: SubjectDelegate!

  private var readingItem: ReadingModelItem?
  private var tableModel: TableModel?
  private var lastSubjectChipTapped: SubjectChip?

  private var subject: TKMSubject!
  private var studyMaterials: TKMStudyMaterials!
  private var studyMaterialsChanged = false
  private var assignment: TKMAssignment?
  private var task: ReviewItem?

  public func setup(services: TKMServices, delegate: SubjectDelegate) {
    self.services = services
    subjectDelegate = delegate
  }

  public func saveStudyMaterials() {
    if studyMaterialsChanged {
      _ = services.localCachingClient.updateStudyMaterial(studyMaterials)
      studyMaterialsChanged = false
    }
  }

  private func addMeanings(_ subject: TKMSubject,
                           studyMaterials: TKMStudyMaterials?,
                           toModel model: MutableTableModel) {
    if subject.meanings.isEmpty {
      return
    }
    let text = renderMeanings(subject: subject, studyMaterials: studyMaterials)
      .string(withFontSize: kFontSize)
    let item = AttributedModelItem(text: text)

    model.add(section: "Meaning")
    model.add(item)
  }

  private func addReadings(_ subject: TKMSubject,
                           studyMaterials _: TKMStudyMaterials?,
                           toModel model: MutableTableModel) {
    let primaryOnly = subject.hasKanji && !Settings.showAllReadings

    // Use the readings if there are any, otherwise, for kana-only vocabs, use the Japanese.
    var readings = subject.readings
    if readings.isEmpty {
      var reading = TKMReading()
      reading.isPrimary = true
      reading.reading = subject.japanese
      readings.append(reading)
    }

    let text = renderReadings(readings: readings,
                              primaryOnly: primaryOnly).string(withFontSize: kFontSize)
    let item = ReadingModelItem(text: text)
    if subject.hasVocabulary, !subject.vocabulary.audio.isEmpty {
      item.setAudio(services.audio, subjectID: subject.id)
    }

    readingItem = item
    model.add(section: "Reading")
    model.add(item)
  }

  private func addComponents(_ subject: TKMSubject,
                             title: String,
                             toModel model: MutableTableModel) {
    if subject.componentSubjectIds.isEmpty {
      return
    }
    let item = SubjectCollectionModelItem(subjects: subject.componentSubjectIds,
                                          localCachingClient: services.localCachingClient,
                                          delegate: self)

    model.add(section: title)
    model.add(item)
  }

  private func addSimilarKanji(_ subject: TKMSubject, toModel model: MutableTableModel) {
    let currentLevel = services.localCachingClient!.getUserInfo()!.level
    var addedSection = false
    for similar in subject.kanji.visuallySimilarKanji {
      guard let subject = services.localCachingClient.getSubject(japanese: String(similar),
                                                                 type: .kanji) else {
        continue
      }
      if subject.level > currentLevel {
        continue
      }
      if !addedSection {
        model.add(section: "Visually Similar Kanji")
        addedSection = true
      }

      let item = SubjectModelItem(subject: subject, delegate: subjectDelegate)
      model.add(item)
    }
  }

  private func addAmalgamationSubjects(_ subject: TKMSubject, toModel model: MutableTableModel) {
    var subjects = [TKMSubject]()
    for subjectID in subject.amalgamationSubjectIds {
      if let subject = services.localCachingClient.getSubject(id: subjectID) {
        subjects.append(subject)
      }
    }

    if subjects.isEmpty {
      return
    }

    subjects.sort { (a, b) -> Bool in
      a.level < b.level
    }

    model.add(section: "Used in")
    for subject in subjects {
      model.add(SubjectModelItem(subject: subject, delegate: subjectDelegate))
    }
  }

  private func addFormattedText(_ text: String,
                                isHint: Bool,
                                toModel model: MutableTableModel)
    -> AttributedModelItem? {
    if text.isEmpty {
      return nil
    }
    let parsedText = parseFormattedText(text)

    var attributes = defaultStringAttrs()
    if isHint {
      attributes[.foregroundColor] = TKMStyle.Color.grey33
    }

    let formattedText = render(formattedText: parsedText, standardAttributes: attributes)
      .replaceFontSize(kFontSize)
    let item = AttributedModelItem(text: formattedText)
    model.add(item)
    return item
  }

  private func addContextSentences(_ subject: TKMSubject, toModel model: MutableTableModel) {
    if subject.vocabulary.sentences.isEmpty {
      return
    }

    model.add(section: "Context Sentences")
    for sentence in subject.vocabulary.sentences {
      model.add(ContextSentenceModelItem(sentence, highlightSubject: subject,
                                         defaultAttributes: defaultStringAttrs(),
                                         fontSize: kFontSize))
    }
  }

  private func addPartsOfSpeech(_ vocab: TKMVocabulary, toModel model: MutableTableModel) {
    let text = vocab.commaSeparatedPartsOfSpeech
    if text.isEmpty {
      return
    }

    model.add(section: "Part of Speech")
    let item = BasicModelItem(style: .default, title: text, subtitle: nil)
    item.titleFont = UIFont.systemFont(ofSize: kFontSize)
    model.add(item)
  }

  static var showAllFieldsCount = 0

  @objc func showAllFields() {
    update(withSubject: subject, studyMaterials: studyMaterials, assignment: assignment, task: nil)

    // If the user keeps pressing the button, prompt them once to enable the showFullAnswer setting.
    if !Settings.seenFullAnswerPrompt {
      SubjectDetailsView.showAllFieldsCount += 1
      if SubjectDetailsView.showAllFieldsCount >= 10 {
        Settings.seenFullAnswerPrompt = true
        let ac = UIAlertController(title: "Always show the full answer?",
                                   message: "If you prefer, Tsurukame can always show the " +
                                     "full answer instead of hiding the part you haven't " +
                                     "answered yet.\n" +
                                     "You can change this in Settings at any time.",
                                   preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Always show", style: .default, handler: { _ in
          Settings.showFullAnswer = true
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        window?.rootViewController?.present(ac, animated: true)
      }
    }
  }

  private func addExplanation(model: MutableTableModel, title: String, text: String,
                              hint: String? = nil, note: String? = nil,
                              noteChangedCallback: ((_ text: String) -> Void)? = nil) {
    if text.isEmpty {
      return
    }
    let hasNote = !(note ?? "").isEmpty
    model.add(section: title)
    let explanationItem = addFormattedText(text, isHint: false,
                                           toModel: model)
    // Add the hint if present.
    if let hint = hint {
      _ = addFormattedText(hint, isHint: true, toModel: model)
    }

    if hasNote, let note = note {
      // If there is a note, add it with its own edit button.
      let attributedNote = NSAttributedString(string: note, attributes: defaultStringAttrs())
      let noteItem = EditableTextModelItem(text: attributedNote,
                                           placeholderText: "Add a note",
                                           rightButtonImage: UIImage(named: "baseline_edit_black_24pt"),
                                           font: UIFont.systemFont(ofSize: kFontSize))
      noteItem.textChangedCallback = noteChangedCallback
      model.add(noteItem)
    } else if noteChangedCallback != nil {
      // If there is no note, add a hidden empty note item that will be set visible by the edit
      // button on the explanation.
      let noteItem = EditableTextModelItem(text: NSAttributedString(),
                                           placeholderText: "Add a note",
                                           rightButtonImage: nil,
                                           font: UIFont.systemFont(ofSize: kFontSize))
      let noteIndex = model.add(noteItem, hidden: true)

      explanationItem?.rightButtonImage = UIImage(named: "baseline_note_add_black_24pt")
      explanationItem?.rightButtonCallback = { [weak self] (cell: AttributedModelCell) in
        cell.removeRightButton()
        // Show the note item.
        self?.tableModel?.setIndexPath(noteIndex, hidden: false)
      }
      noteItem.textChangedCallback = noteChangedCallback
    }
  }

  public func update(withSubject subject: TKMSubject, studyMaterials: TKMStudyMaterials?,
                     assignment: TKMAssignment?, task: ReviewItem?) {
    let model = MutableTableModel(tableView: self), isReview = task != nil
    readingItem = nil
    studyMaterialsChanged = false
    self.subject = subject
    self.studyMaterials = studyMaterials
    if self.studyMaterials == nil {
      self.studyMaterials = TKMStudyMaterials()
      self.studyMaterials.subjectID = subject.id
    }
    self.assignment = assignment
    self.task = task

    let setMeaningNote = { [weak self] (_ text: String) in
      self?.studyMaterials?.meaningNote = text
      self?.studyMaterialsChanged = true
    }
    let setReadingNote = { [weak self] (_ text: String) in
      self?.studyMaterials?.readingNote = text
      self?.studyMaterialsChanged = true
    }

    let meaningAttempted = task?.answeredMeaning == true || task?.answer.meaningWrong == true
    let readingAttempted = task?.answeredReading == true || task?.answer.readingWrong == true
    let meaningShown = !isReview || meaningAttempted
    let readingShown = !isReview || readingAttempted
    let showAllItem = PillModelItem(text: "Show all information",
                                    fontSize: kFontSize) { [weak self] in
      self?.showAllFields()
    }

    if subject.hasRadical {
      if meaningShown {
        addMeanings(subject, studyMaterials: studyMaterials, toModel: model)

        addExplanation(model: model, title: "Mnemonic", text: subject.radical.mnemonic,
                       note: studyMaterials?.meaningNote, noteChangedCallback: setMeaningNote)

        if Settings.showOldMnemonic, !subject.radical.deprecatedMnemonic.isEmpty {
          addExplanation(model: model, title: "Old Mnemonic",
                         text: subject.radical.deprecatedMnemonic)
        }
      } else {
        model.add(showAllItem)
      }
      addAmalgamationSubjects(subject, toModel: model)
    }
    if subject.hasKanji {
      if meaningShown {
        addMeanings(subject, studyMaterials: studyMaterials, toModel: model)
      }
      if readingShown {
        addReadings(subject, studyMaterials: studyMaterials, toModel: model)
      }
      addComponents(subject, title: "Radicals", toModel: model)

      if meaningShown {
        addExplanation(model: model, title: "Meaning Explanation",
                       text: subject.kanji.meaningMnemonic, hint: subject.kanji.meaningHint,
                       note: studyMaterials?.meaningNote, noteChangedCallback: setMeaningNote)
      }
      if meaningShown, readingShown {
        addExplanation(model: model, title: "Reading Explanation",
                       text: subject.kanji.readingMnemonic, hint: subject.kanji.readingHint,
                       note: studyMaterials?.readingNote, noteChangedCallback: setReadingNote)
      }
      if !meaningShown || !readingShown {
        model.add(showAllItem)
      }
      addSimilarKanji(subject, toModel: model)
      addAmalgamationSubjects(subject, toModel: model)
    }
    if subject.hasVocabulary {
      if meaningShown {
        addMeanings(subject, studyMaterials: studyMaterials, toModel: model)
      }
      if readingShown {
        addReadings(subject, studyMaterials: studyMaterials, toModel: model)
      }
      addComponents(subject, title: "Kanji", toModel: model)

      if meaningShown {
        addExplanation(model: model, title: "Meaning Explanation",
                       text: subject.vocabulary.meaningExplanation,
                       note: studyMaterials?.meaningNote, noteChangedCallback: setMeaningNote)
      }
      // Reading explanations often contain the meaning, so require it as well
      if meaningShown, readingShown {
        addExplanation(model: model, title: "Reading Explanation",
                       text: subject.vocabulary.readingExplanation,
                       note: studyMaterials?.readingNote, noteChangedCallback: setReadingNote)
      }
      if !meaningShown || !readingShown {
        model.add(showAllItem)
      }
      addPartsOfSpeech(subject.vocabulary, toModel: model)
      if meaningShown {
        addContextSentences(subject, toModel: model)
      }
    }

    // Your progress, SRS level, next review, first started, reached guru
    if let subjectAssignment = assignment, Settings.showStatsSection {
      model.add(section: "Stats")
      model.add(BasicModelItem(style: .value1, title: "WaniKani Level",
                               subtitle: String(subjectAssignment.level)))

      if subjectAssignment.hasStartedAt {
        if subjectAssignment.hasSrsStageNumber {
          model.add(BasicModelItem(style: .value1, title: "SRS Stage",
                                   subtitle: subjectAssignment.srsStage.description))
        }
        model.add(BasicModelItem(style: .value1, title: "Started",
                                 subtitle: statsDateFormatter
                                   .string(from: subjectAssignment.startedAtDate)))
        if subjectAssignment.hasAvailableAt {
          model.add(BasicModelItem(style: .value1, title: "Next Review",
                                   subtitle: statsDateFormatter
                                     .string(from: subjectAssignment.availableAtDate)))
        }
        if subjectAssignment.hasPassedAt {
          model.add(BasicModelItem(style: .value1, title: "Passed",
                                   subtitle: statsDateFormatter
                                     .string(from: subjectAssignment.passedAtDate)))
        }
        if subjectAssignment.hasBurnedAt {
          model.add(BasicModelItem(style: .value1, title: "Burned",
                                   subtitle: statsDateFormatter
                                     .string(from: subjectAssignment.burnedAtDate)))
        }
      }

      // TODO: When possible in the API, add a resurrect button.
    }

    // Add the artwork section.
    if #available(iOS 15.0, *), ArtworkManager.contains(subjectID: subject.id) {
      model.add(section: "ArtWork by @AmandaBear")
      model.add(ArtworkModelItem(subjectID: subject.id))
    } else {
      // Fallback on earlier versions
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

  override func didMoveToSuperview() {
    // Break the reference cycle between the table model and the table view (self) when the view
    // is removed from the hierarcy.
    if superview == nil {
      tableModel = nil
    }
  }

  // MARK: - SubjectChipDelegate

  func didTapSubjectChip(_ chip: SubjectChip) {
    lastSubjectChipTapped = chip

    chip.backgroundColor = TKMStyle.Color.grey80
    if let subject = chip.subject {
      subjectDelegate.didTapSubject(subject)
    }
  }
}
