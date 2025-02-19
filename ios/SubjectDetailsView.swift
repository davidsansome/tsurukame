// Copyright 2025 David Sansome
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
      strings.append(attrString(meaning.meaning.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
  }
  if let studyMaterials = studyMaterials {
    for meaning in studyMaterials.meaningSynonyms {
      strings.append(attrString(meaning.trimmingCharacters(in: .whitespacesAndNewlines),
                                attrs: [.foregroundColor: kMeaningSynonymColor]))
    }
  }
  for meaning in subject.meanings {
    if meaning.type != .primary, meaning.type != .blacklist,
       meaning.type != .auxiliaryWhitelist || !subject.hasRadical || Settings.showOldMnemonic {
      let font = UIFont.systemFont(ofSize: kFontSize, weight: .light)
      strings.append(attrString(meaning.meaning.trimmingCharacters(in: .whitespacesAndNewlines),
                                attrs: [.font: font]))
    }
  }
  return join(strings, with: ", ")
}

private func renderReadings(readings: [TKMReading], primaryOnly: Bool) -> NSAttributedString {
  var strings = [NSAttributedString]()
  for reading in readings {
    if reading.isPrimary {
      var font = UIFont.systemFont(ofSize: kFontSize, weight: .regular)
      if !primaryOnly, readings.count > 1 {
        font = UIFont.systemFont(ofSize: kFontSize, weight: .bold)
      }
      strings
        .append(attrString(reading.displayText(useKatakanaForOnyomi: Settings.useKatakanaForOnyomi),
                           attrs: [.font: font as Any]))
    }
  }
  if !primaryOnly {
    for reading in readings {
      if !reading.isPrimary {
        strings
          .append(attrString(reading
              .displayText(useKatakanaForOnyomi: Settings.useKatakanaForOnyomi)))
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
   .backgroundColor: UIColor.clear]
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

    let scaledSectionHeaderHeight = UIFontMetrics.default.scaledValue(for: kSectionHeaderHeight)

    sectionHeaderHeight = scaledSectionHeaderHeight
    estimatedSectionHeaderHeight = scaledSectionHeaderHeight
    sectionFooterHeight = kSectionFooterHeight
    estimatedSectionFooterHeight = kSectionFooterHeight
  }

  private var services: TKMServices!
  private weak var subjectDelegate: SubjectDelegate!

  private var readingItem: ReadingModelItem?
  private var tableModel: MutableTableModel?
  private var lastSubjectChipTapped: SubjectChip?

  private var studyMaterials: TKMStudyMaterials!
  private var studyMaterialsChanged = false
  private var synonymSection: Int?

  // Items that are hidden, and will be shown when the Show All button is pressed.
  private var hiddenIndexPaths = [IndexPath]()

  // Button that shows all the hiddenIndexPaths.
  private var showAllButton: IndexPath?

  public func setup(services: TKMServices, delegate: SubjectDelegate) {
    self.services = services
    subjectDelegate = delegate
  }

  public func saveStudyMaterials() {
    if !studyMaterialsChanged {
      return
    }

    if let synonymSection = synonymSection {
      // Each synonym will have an EditableTextModelItem in this section.
      var synonyms = [String]()
      let rows = tableModel!.tableView(tableModel!.tableView,
                                       numberOfRowsInSection: synonymSection)
      for row in 0 ..< rows {
        let item = tableModel?.item(inSection: synonymSection, atRow: row)
        guard let item = item as? EditableTextModelItem else { continue }

        // Don't count hidden items - they were old synonyms that were deleted.
        if tableModel!.isIndexPathHidden(IndexPath(row: row, section: synonymSection)) {
          continue
        }

        let text = item.text.string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
          synonyms.append(text)
        }
      }
      studyMaterials.meaningSynonyms = synonyms
    }

    _ = services.localCachingClient.updateStudyMaterial(studyMaterials)
    studyMaterialsChanged = false
  }

  private func addMeanings(_ subject: TKMSubject,
                           studyMaterials: TKMStudyMaterials?,
                           toModel model: MutableTableModel) -> IndexPath? {
    if subject.meanings.isEmpty {
      return nil
    }
    let text = renderMeanings(subject: subject, studyMaterials: studyMaterials)
      .string(withFontSize: kFontSize)
    let item = AttributedModelItem(text: text)

    let sectionIndexPath = model.add(section: "Meaning")
    let itemIndexPath = model.add(item)

    item.rightButtonImage = Asset.baselineEditBlack24pt.image
    item.rightButtonCallback = { [unowned self, unowned model, unowned item] cell in
      self.performBatchUpdates { [unowned self, unowned model, unowned item] in
        self.editMeaningSynonyms(item: item, itemIndexPath: itemIndexPath, cell: cell,
                                 subject: subject,
                                 studyMaterials: studyMaterials, toModel: model)
      }
    }

    return sectionIndexPath
  }

  private func editMeaningSynonyms(item: AttributedModelItem, itemIndexPath: IndexPath,
                                   cell: AttributedModelCell,
                                   subject: TKMSubject,
                                   studyMaterials: TKMStudyMaterials?,
                                   toModel model: MutableTableModel) {
    // Remove the synonyms from the text.
    item.rightButtonImage = nil
    item.text = renderMeanings(subject: subject, studyMaterials: nil)
      .string(withFontSize: kFontSize)
    cell.update()
    reloadRows(at: [itemIndexPath], with: .fade)

    // Add rows for each of the synonyms.
    if let studyMaterials = studyMaterials {
      for synonym in studyMaterials.meaningSynonyms {
        let synonymItem = EditableTextModelItem(text: NSAttributedString(string: synonym),
                                                placeholderText: "",
                                                rightButtonImage: Asset.baselineCancelBlack24pt
                                                  .image,
                                                font: UIFont.systemFont(ofSize: kFontSize))
        let indexPath = model.add(synonymItem, toSection: itemIndexPath.section)
        synonymItem.rightButtonCallback = { [unowned self] _ in
          self.tableModel?.setIndexPath(indexPath, hidden: true)
        }
      }
    }

    // Add an empty row for a new synonym.
    addNewSynonymItem(model: model, itemIndexPath: itemIndexPath)

    // We're editing the synonyms. Save the section index so we can get all the edited items later.
    synonymSection = itemIndexPath.section
    studyMaterialsChanged = true
  }

  private func addNewSynonymItem(model: MutableTableModel, itemIndexPath: IndexPath) {
    let item = EditableTextModelItem(text: NSAttributedString(),
                                     placeholderText: "Add synonym...",
                                     rightButtonImage: nil,
                                     font: UIFont.systemFont(ofSize: kFontSize))
    item.becomeFirstResponderImmediately = false
    item.textChangedCallback = { [weak self] _ in
      self?.addNewSynonymItem(model: model, itemIndexPath: itemIndexPath)
      item.textChangedCallback = nil
    }
    model.add(item, toSection: itemIndexPath.section)
  }

  private func addReadings(_ subject: TKMSubject,
                           studyMaterials _: TKMStudyMaterials?,
                           toModel model: MutableTableModel) -> IndexPath {
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
    let indexPath = model.add(section: "Reading")
    model.add(item)
    return indexPath
  }

  private func addComponents(_ subject: TKMSubject,
                             title: String,
                             toModel model: MutableTableModel) {
    if subject.componentSubjectIds.isEmpty {
      return
    }
    let item = SubjectCollectionModelItem(subjects: subject.componentSubjectIds,
                                          fontSize: kFontSize,
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

    subjects.sort { a, b -> Bool in
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

  private func addContextSentences(_ subject: TKMSubject,
                                   toModel model: MutableTableModel) -> IndexPath? {
    if subject.vocabulary.sentences.isEmpty {
      return nil
    }

    let indexPath = model.add(section: "Context Sentences")
    for sentence in subject.vocabulary.sentences {
      model.add(ContextSentenceModelItem(sentence, highlightSubject: subject,
                                         defaultAttributes: defaultStringAttrs(),
                                         fontSize: kFontSize))
    }
    return indexPath
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
    if hiddenIndexPaths.isEmpty {
      return
    }

    // Deletes need to happen before insertions.
    performBatchUpdates {
      // Hide the show all button.
      if let showAllButton = showAllButton {
        tableModel?.setIndexPath(showAllButton, hidden: true)
      }

      // Show all the hidden rows.
      for indexPath in hiddenIndexPaths {
        tableModel?.setIndexPath(indexPath, hidden: false)
      }
    }

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
                              noteChangedCallback: ((_ text: String) -> Void)? = nil)
    -> IndexPath? {
    if text.isEmpty {
      return nil
    }
    let hasNote = !(note ?? "").isEmpty
    let indexPath = model.add(section: title)
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
                                           rightButtonImage: Asset.baselineEditBlack24pt.image,
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

      explanationItem?.rightButtonImage = Asset.baselineNoteAddBlack24pt.image
      explanationItem?.rightButtonCallback = { [unowned self] (cell: AttributedModelCell) in
        cell.removeRightButton()
        // Show the note item.
        self.tableModel?.setIndexPath(noteIndex, hidden: false)
      }
      noteItem.textChangedCallback = noteChangedCallback
    }
    return indexPath
  }

  private func addShowAllButton(hiddenIndexPaths: [IndexPath?],
                                model: MutableTableModel) {
    self.hiddenIndexPaths = hiddenIndexPaths.filter {
      $0 != nil
    } as! [IndexPath]

    if self.hiddenIndexPaths.isEmpty {
      return
    }

    for indexPath in self.hiddenIndexPaths {
      model.setIndexPath(indexPath, hidden: true)
    }

    showAllButton = model.addSection()
    model.add(PillModelItem(text: "Show all information",
                            fontSize: kFontSize) { [weak self] in
        self?.showAllFields()
      })
  }

  public func update(withSubject subject: TKMSubject, studyMaterials: TKMStudyMaterials?,
                     assignment: TKMAssignment?, task: ReviewItem?) {
    if FeatureFlags.dumpSubjectTextproto {
      print(subject)
    }

    let model = MutableTableModel(tableView: self), isReview = task != nil
    model.useSectionHeaderHeightFromView = true

    readingItem = nil
    studyMaterialsChanged = false
    if studyMaterials != nil {
      self.studyMaterials = studyMaterials
    } else {
      self.studyMaterials = TKMStudyMaterials()
      self.studyMaterials.subjectID = subject.id
    }

    let setMeaningNote = { [weak self] (_ text: String) in
      self?.studyMaterials.meaningNote = text
      self?.studyMaterialsChanged = true
    }
    let setReadingNote = { [weak self] (_ text: String) in
      self?.studyMaterials.readingNote = text
      self?.studyMaterialsChanged = true
    }

    let meaningAttempted = task?.answeredMeaning == true || task?.answer.meaningWrong == true
    let readingAttempted = task?.answeredReading == true || task?.answer.readingWrong == true
    let meaningShown = !isReview || meaningAttempted
    let readingShown = !isReview || readingAttempted

    if subject.hasRadical {
      let meanings = addMeanings(subject, studyMaterials: studyMaterials, toModel: model)

      let mnemonic = addExplanation(model: model, title: "Mnemonic", text: subject.radical.mnemonic,
                                    note: studyMaterials?.meaningNote,
                                    noteChangedCallback: setMeaningNote)

      var oldMnemonic: IndexPath?
      if Settings.showOldMnemonic, !subject.radical.deprecatedMnemonic.isEmpty {
        oldMnemonic = addExplanation(model: model, title: "Old Mnemonic",
                                     text: subject.radical.deprecatedMnemonic)
      }

      if !meaningShown {
        addShowAllButton(hiddenIndexPaths: [meanings, mnemonic, oldMnemonic], model: model)
      }
      addAmalgamationSubjects(subject, toModel: model)
    }

    if subject.hasKanji {
      let meanings = addMeanings(subject, studyMaterials: studyMaterials, toModel: model)
      let readings = addReadings(subject, studyMaterials: studyMaterials, toModel: model)

      addComponents(subject, title: "Radicals", toModel: model)

      let meaningExplanation = addExplanation(model: model, title: "Meaning Explanation",
                                              text: subject.kanji.meaningMnemonic,
                                              hint: subject.kanji.meaningHint,
                                              note: studyMaterials?.meaningNote,
                                              noteChangedCallback: setMeaningNote)
      let readingExplanation = addExplanation(model: model, title: "Reading Explanation",
                                              text: subject.kanji.readingMnemonic,
                                              hint: subject.kanji.readingHint,
                                              note: studyMaterials?.readingNote,
                                              noteChangedCallback: setReadingNote)

      if !meaningShown, !readingShown {
        addShowAllButton(hiddenIndexPaths: [meanings, readings, meaningExplanation,
                                            readingExplanation],
                         model: model)
      } else if !meaningShown {
        // Reading explanations often contain the meaning, so hide it as well.
        addShowAllButton(hiddenIndexPaths: [meanings, meaningExplanation, readingExplanation],
                         model: model)
      } else if !readingShown {
        addShowAllButton(hiddenIndexPaths: [readings, readingExplanation], model: model)
      }

      addSimilarKanji(subject, toModel: model)
      addAmalgamationSubjects(subject, toModel: model)
    }

    if subject.hasVocabulary {
      let meanings = addMeanings(subject, studyMaterials: studyMaterials, toModel: model)
      let readings = addReadings(subject, studyMaterials: studyMaterials, toModel: model)

      addComponents(subject, title: "Kanji", toModel: model)

      let meaningExplanation = addExplanation(model: model, title: "Meaning Explanation",
                                              text: subject.vocabulary.meaningExplanation,
                                              note: studyMaterials?.meaningNote,
                                              noteChangedCallback: setMeaningNote)
      let readingExplanation = addExplanation(model: model, title: "Reading Explanation",
                                              text: subject.vocabulary.readingExplanation,
                                              note: studyMaterials?.readingNote,
                                              noteChangedCallback: setReadingNote)

      if !meaningShown, !readingShown {
        addShowAllButton(hiddenIndexPaths: [meanings, readings, meaningExplanation,
                                            readingExplanation],
                         model: model)
      } else if !meaningShown {
        // Reading explanations often contain the meaning, so hide it as well.
        addShowAllButton(hiddenIndexPaths: [meanings, meaningExplanation, readingExplanation],
                         model: model)
      } else if !readingShown {
        addShowAllButton(hiddenIndexPaths: [readings, readingExplanation], model: model)
      }

      // Add context sentences after the Show All button, since they're quite big.
      let contextSentences = addContextSentences(subject, toModel: model)
      if !meaningShown, let contextSentences = contextSentences {
        model.setIndexPath(contextSentences, hidden: true)
        hiddenIndexPaths.append(contextSentences)
      }

      addPartsOfSpeech(subject.vocabulary, toModel: model)
    }

    // Your progress, SRS level, next review, first started, reached guru
    if let subjectAssignment = assignment, Settings.showStatsSection {
      if subjectAssignment.hasLevel {
        model.add(section: "Stats")
        model.add(BasicModelItem(style: .value1, title: "WaniKani Level",
                                 subtitle: String(subjectAssignment.level)))
      }

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

    // Add the Artwork section.
    if #available(iOS 15.0, *), Settings.showArtwork,
       services.reachability.isReachable(),
       ArtworkManager.contains(subjectID: subject.id) {
      model.add(section: "Artwork by @AmandaBear")
      model.add(ArtworkModelItem(subjectID: subject.id))
    }

    if FeatureFlags.showSubjectDeveloperOptions {
      model.add(section: "Developer options")
      model.add(BasicModelItem(style: .default, title: "Open practice review") { [unowned self] in
        self.subjectDelegate.openPracticeReview(subject)
      })
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
