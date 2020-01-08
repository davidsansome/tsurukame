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

import ClockKit
import os

class ComplicationController: NSObject, CLKComplicationDataSource {
  let TsurukameHighlightColor = UIColor.red

  // MARK: - Timeline Configuration

  func getSupportedTimeTravelDirections(for _: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
    handler([.forward])
  }

  func getTimelineStartDate(for _: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
    handler(nil)
  }

  func getTimelineEndDate(for _: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
    handler(DataManager.sharedInstance.dataStaleAfter())
  }

  func getPrivacyBehavior(for _: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
    handler(.showOnLockScreen)
  }

  // MARK: - Timeline Population

  func getCurrentTimelineEntry(for complication: CLKComplication,
                               withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
    if DataManager.sharedInstance.dataIsStale() {
      handler(staleTimelineEntry(complication: complication))
      return
    }

    if let template = templateFor(complication,
                                  userData: DataManager.sharedInstance.latestData,
                                  dataSource: DataManager.sharedInstance.dataSource) {
      let date = Date()
      let entry = CLKComplicationTimelineEntry(date: date, complicationTemplate: template)
      handler(entry)
    } else {
      handler(nil)
    }
  }

  func getTimelineEntries(for _: CLKComplication, before _: Date, limit _: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
    // Call the handler with the timeline entries prior to the given date
    handler(nil)
  }

  func getTimelineEntries(for complication: CLKComplication, after: Date, limit _: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
    // TODO: Transfer upcoming review info so we can handle offline complication refreshes.
    // Call the handler with the timeline entries after to the given date
    if let staleDate = DataManager.sharedInstance.dataStaleAfter(),
      after.distance(to: staleDate) >= 0,
      let staleEntry = staleTimelineEntry(complication: complication) {
      handler([staleEntry])
    } else {
      handler(nil)
    }
  }

  func staleTimelineEntry(complication: CLKComplication) -> CLKComplicationTimelineEntry? {
    if let staleDate = DataManager.sharedInstance.dataStaleAfter(), let template = templateForStaleData(complication) {
      return CLKComplicationTimelineEntry(date: staleDate, complicationTemplate: template)
    }
    return nil
  }

  // MARK: - Placeholder Templates

  func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
    // This method will be called once per supported complication, and the results will be cached
    let template = templateFor(complication,
                               userData: DataManager.sharedInstance.latestData ?? [
                                 WatchHelper.KeyReviewCount: 8,
                                 WatchHelper.KeyReviewNextHourCount: 3,
                                 WatchHelper.KeyLevelCurrent: 6,
                                 WatchHelper.KeyLevelTotal: 80,
                                 WatchHelper.KeyLevelLearned: 12,
                                 WatchHelper.KeyLevelHalf: false,
                                 WatchHelper.KeyNextReviewAt: Date().addingTimeInterval(TimeInterval(300)).timeIntervalSince1970,
                               ],
                               dataSource: DataManager.sharedInstance.dataSource)
    handler(template)
  }

  // MARK: - Internal helpers

  func templateFor(_ complication: CLKComplication, userData: UserData?, dataSource: ComplicationDataSource) -> CLKComplicationTemplate? {
    // TODO: Drive data source based on complication family in some cases?
    switch dataSource {
    case .ReviewCounts:
      return templateForReviewCount(complication, userData: userData)
    case .Level:
      return templateForLevel(complication, userData: userData)
    case .Character:
      return templateForCharacter(complication, userData: userData)
    }
  }

  func templateForReviewCount(_ complication: CLKComplication, userData: UserData?) -> CLKComplicationTemplate? {
    var reviewsPending: Int = 0
    var nextHour: Int = 0
    var nextReview: Date?
    if let data = userData {
      if let reviewCount = data[WatchHelper.KeyReviewCount] as? Int {
        reviewsPending = reviewCount
      }
      if let nextHourCount = data[WatchHelper.KeyReviewNextHourCount] as? Int {
        nextHour = nextHourCount
      }
      if let nextReviewAt = data[WatchHelper.KeyNextReviewAt] as? EpochTimeInt {
        nextReview = Date(timeIntervalSince1970: TimeInterval(nextReviewAt))
      }
    }

    switch complication.family {
    case .circularSmall:
      let template = CLKComplicationTemplateCircularSmallSimpleText()
      template.textProvider = CLKTextProvider(format: "%d", reviewsPending)
      return template
    case .extraLarge:
      let template = CLKComplicationTemplateExtraLargeStackText()
      template.line1TextProvider = CLKTextProvider(format: "REVIEWS")
      template.line2TextProvider = CLKTextProvider(format: "%d", reviewsPending)
    case .modularSmall:
      if reviewsPending > 0 {
        let template = CLKComplicationTemplateModularSmallStackText()
        template.line1TextProvider = CLKSimpleTextProvider(text: "now")
        template.line2TextProvider = CLKTextProvider(format: "%d", reviewsPending)
        if reviewsPending > 10 {
          template.highlightLine2 = true
        }
        return template
      } else if nextHour > 0 || nextReview == nil {
        let template = CLKComplicationTemplateModularSmallStackText()
        template.line1TextProvider = CLKSimpleTextProvider(text: "next")
        template.line2TextProvider = CLKTextProvider(format: "%d", nextHour)
        return template
      } else {
        let template = CLKComplicationTemplateModularSmallStackText()
        template.line1TextProvider = CLKSimpleTextProvider(text: "next")
        template.line2TextProvider = relativeDateProvider(date: nextReview!)
        return template
      }
    case .modularLarge:
      let template = CLKComplicationTemplateModularLargeTable()
      if let img = UIImage(named: "miniCrab") {
        template.headerImageProvider = CLKImageProvider(onePieceImage: img)
      }
      template.headerTextProvider = CLKSimpleTextProvider(text: "Reviews")
      template.row1Column1TextProvider = CLKTextProvider(format: "%d", reviewsPending)
      template.row1Column2TextProvider = CLKSimpleTextProvider(text: "now")
      if nextHour > 0 || nextReview == nil {
        template.row2Column1TextProvider = CLKTextProvider(format: "%d", nextHour)
        template.row2Column2TextProvider = CLKSimpleTextProvider(text: "next hour")
      } else {
        template.row2Column1TextProvider = relativeDateProvider(date: nextReview!)
        template.row2Column2TextProvider = CLKSimpleTextProvider(text: "until next")
      }
      return template
    case .utilitarianSmall:
      fallthrough
    case .utilitarianSmallFlat:
      let template = CLKComplicationTemplateUtilitarianSmallFlat()
      template.textProvider = CLKTextProvider(format: "NOW %d", reviewsPending)
      return template
    case .utilitarianLarge:
      let template = CLKComplicationTemplateUtilitarianLargeFlat()
      // TODO: Pluralize
      template.textProvider = CLKTextProvider(format: "%d REVIEWS", reviewsPending)
      return template
    case .graphicCorner:
      let template = CLKComplicationTemplateGraphicCornerStackText()
      template.outerTextProvider = CLKTextProvider(format: "%d NOW", reviewsPending)
      if nextHour > 0 || nextReview == nil {
        template.innerTextProvider = CLKTextProvider(format: "%d next hour", nextHour)
      } else {
        template.innerTextProvider = CLKTextProvider(format: "%@ until next", relativeDateProvider(date: nextReview!))
      }
      return template
    case .graphicCircular:
      if reviewsPending > 0 {
        let template = CLKComplicationTemplateGraphicCircularStackImage()
        template.line2TextProvider = CLKTextProvider(format: "%d", reviewsPending)
        if let img = UIImage(named: "miniCrab") {
          template.line1ImageProvider = CLKFullColorImageProvider(fullColorImage: img)
        }
        return template
      } else if nextHour > 0 || nextReview == nil {
        let template = CLKComplicationTemplateGraphicCircularStackText()
        template.line1TextProvider = CLKSimpleTextProvider(text: "next")
        template.line2TextProvider = CLKTextProvider(format: "%d", nextHour)
        return template
      } else {
        let template = CLKComplicationTemplateGraphicCircularStackText()
        template.line1TextProvider = CLKSimpleTextProvider(text: "next")
        template.line2TextProvider = relativeDateProvider(date: nextReview!)
        return template
      }
    case .graphicBezel:
      let template = CLKComplicationTemplateGraphicBezelCircularText()
      if let img = UIImage(named: "miniCrab") {
        let circularTemplate = CLKComplicationTemplateGraphicCircularImage()
        circularTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: img)
        template.circularTemplate = circularTemplate
      } else {
        let circularTemplate = CLKComplicationTemplateGraphicCircularStackText()
        circularTemplate.line1TextProvider = CLKSimpleTextProvider(text: "")
        circularTemplate.line2TextProvider = CLKSimpleTextProvider(text: "")
        template.circularTemplate = circularTemplate
      }
      if nextHour > 0 || nextReview == nil {
        template.textProvider = CLKTextProvider(format: "%d NOW • %d next hour", reviewsPending, nextHour)
      } else {
        template.textProvider = relativeDateProvider(date: nextReview!)
      }
      return template
    case .graphicRectangular:
      let template = CLKComplicationTemplateGraphicRectangularStandardBody()
      template.headerTextProvider = CLKTextProvider(format: "Reviews")
      template.body1TextProvider = CLKTextProvider(format: "%d now", reviewsPending)
      if nextHour > 0 || nextReview == nil {
        template.body2TextProvider = CLKTextProvider(format: "%d next hour", nextHour)
      } else {
        template.body2TextProvider = CLKTextProvider(format: "%@ until next", relativeDateProvider(date: nextReview!))
      }

      if let img = UIImage(named: "miniCrab") {
        template.headerImageProvider = CLKFullColorImageProvider(fullColorImage: img)
      }
      return template
    @unknown default:
      return nil
    }
    return nil
  }

  func templateForLevel(_ complication: CLKComplication, userData: UserData?) -> CLKComplicationTemplate? {
    let currentLevel = userData?[WatchHelper.KeyLevelCurrent] as? Int ?? 0
    let learned = userData?[WatchHelper.KeyLevelLearned] as? Int ?? 0
    let total = userData?[WatchHelper.KeyLevelTotal] as? Int ?? 0
    let halfLevel = userData?[WatchHelper.KeyLevelHalf] as? Bool ?? false
    let fillFraction = Float(learned) / Float(total)

    let levelTextProvider: CLKTextProvider
    let levelShortTextProvider: CLKTextProvider
    if halfLevel {
      levelTextProvider = CLKTextProvider(format: "Level %.1f", Float(currentLevel) + 0.5)
      levelShortTextProvider = CLKTextProvider(format: "%.1f", Float(currentLevel) + 0.5)
    } else {
      levelTextProvider = CLKTextProvider(format: "Level %d", currentLevel)
      levelShortTextProvider = CLKTextProvider(format: "%d", currentLevel)
    }

    switch complication.family {
    case .circularSmall:
      let template = CLKComplicationTemplateCircularSmallRingText()
      template.textProvider = levelShortTextProvider
      template.ringStyle = .closed
      template.fillFraction = fillFraction
      return template
    case .extraLarge:
      let template = CLKComplicationTemplateExtraLargeRingText()
      template.textProvider = levelShortTextProvider
      template.fillFraction = fillFraction
      template.ringStyle = .closed
      return template
    case .modularSmall:
      let template = CLKComplicationTemplateModularSmallStackImage()
      template.line2TextProvider = levelShortTextProvider
      if let img = UIImage(named: "miniCrab") {
        template.line1ImageProvider = CLKImageProvider(onePieceImage: img)
      }
      return template
    case .modularLarge:
      let template = CLKComplicationTemplateModularLargeTable()
      if let img = UIImage(named: "miniCrab") {
        template.headerImageProvider = CLKImageProvider(onePieceImage: img)
      }
      template.headerTextProvider = levelTextProvider
      template.row1Column1TextProvider = CLKTextProvider(format: "%d", learned)
      template.row1Column2TextProvider = CLKSimpleTextProvider(text: "learned")
      template.row2Column1TextProvider = CLKTextProvider(format: "%d", total - learned)
      template.row2Column2TextProvider = CLKSimpleTextProvider(text: "remaining")
      return template
    case .utilitarianSmall:
      fallthrough
    case .utilitarianSmallFlat:
      let template = CLKComplicationTemplateUtilitarianSmallFlat()
      template.textProvider = levelShortTextProvider
      if let img = UIImage(named: "miniCrab") {
        template.imageProvider = CLKImageProvider(onePieceImage: img)
        template.imageProvider?.tintColor = TsurukameHighlightColor
      }
      return template
    case .utilitarianLarge:
      let template = CLKComplicationTemplateUtilitarianLargeFlat()
      if fillFraction > 0.8 {
        template.textProvider = CLKTextProvider(format: "%@ • %d left", levelTextProvider, total - learned)
      } else {
        template.textProvider = CLKTextProvider(format: "%@ • %d/%d", levelTextProvider, learned, total)
      }
      return template
    case .graphicCorner:
      let template = CLKComplicationTemplateGraphicCornerGaugeText()
      template.outerTextProvider = levelShortTextProvider
      template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: TsurukameHighlightColor, fillFraction: fillFraction)
      template.trailingTextProvider = CLKTextProvider(format: "→%d", total - learned)
      return template
    case .graphicCircular:
      let template = CLKComplicationTemplateGraphicCircularOpenGaugeRangeText()
      template.centerTextProvider = CLKTextProvider(format: "%d", learned)
      template.gaugeProvider = CLKSimpleGaugeProvider(style: .ring, gaugeColor: TsurukameHighlightColor, fillFraction: fillFraction)
      template.leadingTextProvider = CLKSimpleTextProvider(text: "0")
      template.trailingTextProvider = CLKTextProvider(format: "%d", total)
      return template
    case .graphicBezel:
      let circleTemplate = CLKComplicationTemplateGraphicCircularOpenGaugeRangeText()
      circleTemplate.centerTextProvider = CLKTextProvider(format: "%d", learned)
      circleTemplate.gaugeProvider = CLKSimpleGaugeProvider(style: .ring, gaugeColor: TsurukameHighlightColor, fillFraction: fillFraction)
      circleTemplate.leadingTextProvider = CLKSimpleTextProvider(text: "0")
      circleTemplate.trailingTextProvider = CLKTextProvider(format: "%d", total)
      let template = CLKComplicationTemplateGraphicBezelCircularText()
      template.textProvider = CLKTextProvider(format: "%@ • %.0f%% complete", levelTextProvider, (Float(learned) / Float(total)) * 100.0)
      template.circularTemplate = circleTemplate
      return template
    case .graphicRectangular:
      let template = CLKComplicationTemplateGraphicRectangularTextGauge()
      template.headerTextProvider = levelTextProvider
      template.body1TextProvider = CLKTextProvider(format: "%d of %d learned", learned, total)
      if let img = UIImage(named: "miniCrab") {
        template.headerImageProvider = CLKFullColorImageProvider(fullColorImage: img)
      }
      template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: TsurukameHighlightColor, fillFraction: fillFraction)
      return template
    default:
      return nil
    }
  }

  func templateForStaleData(_ complication: CLKComplication) -> CLKComplicationTemplate? {
    let dashTextProvider = CLKSimpleTextProvider(text: "-")

    switch complication.family {
    case .circularSmall:
      let template = CLKComplicationTemplateCircularSmallSimpleText()
      template.textProvider = dashTextProvider
      return template
    case .extraLarge:
      let template = CLKComplicationTemplateExtraLargeStackText()
      template.line1TextProvider = CLKTextProvider(format: "REVIEWS")
      template.line2TextProvider = CLKSimpleTextProvider(text: "unknown")
    case .modularSmall:
      let template = CLKComplicationTemplateModularSmallStackText()
      template.line1TextProvider = CLKSimpleTextProvider(text: "now")
      template.line2TextProvider = dashTextProvider
      return template
    case .modularLarge:
      let template = CLKComplicationTemplateModularLargeTable()
      if let img = UIImage(named: "miniCrab") {
        template.headerImageProvider = CLKImageProvider(onePieceImage: img)
      }
      template.headerTextProvider = CLKSimpleTextProvider(text: "Reviews")
      template.row1Column1TextProvider = dashTextProvider
      template.row1Column2TextProvider = CLKSimpleTextProvider(text: "now")
      template.row2Column1TextProvider = dashTextProvider
      template.row2Column2TextProvider = CLKSimpleTextProvider(text: "next hour")
      return template
    case .utilitarianSmall:
      fallthrough
    case .utilitarianSmallFlat:
      let template = CLKComplicationTemplateUtilitarianSmallFlat()
      if let img = UIImage(named: "miniCrab") {
        template.imageProvider = CLKImageProvider(onePieceImage: img)
      }
      template.textProvider = dashTextProvider
      return template
    case .utilitarianLarge:
      let template = CLKComplicationTemplateUtilitarianLargeFlat()
      // TODO: Pluralize
      template.textProvider = CLKSimpleTextProvider(text: "data stale")
      return template
    case .graphicCorner:
      let template = CLKComplicationTemplateGraphicCornerStackText()
      template.outerTextProvider = CLKSimpleTextProvider(text: "stale")
      template.innerTextProvider = CLKSimpleTextProvider(text: "open phone app")
      return template
    case .graphicCircular:
      let template = CLKComplicationTemplateGraphicCircularStackText()
      template.line1TextProvider = CLKSimpleTextProvider(text: "next")
      template.line2TextProvider = dashTextProvider
    case .graphicBezel:
      let template = CLKComplicationTemplateGraphicBezelCircularText()
      if let img = UIImage(named: "miniCrab") {
        let circularTemplate = CLKComplicationTemplateGraphicCircularImage()
        circularTemplate.imageProvider = CLKFullColorImageProvider(fullColorImage: img)
        template.circularTemplate = circularTemplate
      } else {
        let circularTemplate = CLKComplicationTemplateGraphicCircularStackText()
        circularTemplate.line1TextProvider = CLKSimpleTextProvider(text: "")
        circularTemplate.line2TextProvider = CLKSimpleTextProvider(text: "")
        template.circularTemplate = circularTemplate
      }
      template.textProvider = dashTextProvider
      return template
    case .graphicRectangular:
      let template = CLKComplicationTemplateGraphicRectangularStandardBody()
      template.headerTextProvider = CLKTextProvider(format: "Reviews")
      template.body1TextProvider = dashTextProvider
      template.body2TextProvider = dashTextProvider

      if let img = UIImage(named: "miniCrab") {
        template.headerImageProvider = CLKFullColorImageProvider(fullColorImage: img)
      }
      return template
    @unknown default:
      return nil
    }
    return nil
  }

  /**
   Currently in testing: Is it useful to see a random character?
   */
  func templateForCharacter(_ complication: CLKComplication, userData _: UserData?) -> CLKComplicationTemplate? {
    // TODO: Get the list of characters to pick from
    let character: String = ["森", "後"].randomElement()!
    let vocab: String = ["落とす"].randomElement()!
    let px = 70
    let size = CGSize(width: px, height: px)

    switch complication.family {
    case .graphicBezel:
      let template = CLKComplicationTemplateGraphicBezelCircularText()
      template.textProvider = CLKSimpleTextProvider(text: vocab)
      let circ = CLKComplicationTemplateGraphicCircularClosedGaugeText()
      circ.centerTextProvider = CLKSimpleTextProvider(text: "30")
      circ.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: TsurukameHighlightColor, fillFraction: 3 / 10)
      template.circularTemplate = circ
      return template
    case .graphicCircular:
      // Attempt to use an image so we can have a larger text item
      if let img = textToImage(drawText: character, size: size) {
        let template = CLKComplicationTemplateGraphicCircularClosedGaugeImage()
        template.imageProvider = CLKFullColorImageProvider(fullColorImage: img)
        template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: TsurukameHighlightColor, fillFraction: 3 / 10)
        return template
      } else {
        let template = CLKComplicationTemplateGraphicCircularStackText()
        template.line1TextProvider = CLKSimpleTextProvider(text: "")
        template.line2TextProvider = CLKSimpleTextProvider(text: character)
        return template
      }
    default:
      return nil
    }
  }

  func relativeDateProvider(date: Date) -> CLKRelativeDateTextProvider {
    // Always use hour because the complication cache does not call often enough
    // to vary this unit.
    return CLKRelativeDateTextProvider(date: date, style: .offsetShort, units: .hour)
  }

  /**
   Create a UIImage with a kanji character centered in it. Used to display larger
   text.
   */
  func textToImage(drawText text: String, size: CGSize) -> UIImage? {
    let textColor = UIColor.white
    let textFont = UIFont.systemFont(ofSize: 26)

    let scale: CGFloat = 2.0
    UIGraphicsBeginImageContextWithOptions(size, false, scale)

    let textStyle = NSMutableParagraphStyle()
    textStyle.alignment = .center

    let textFontAttributes = [
      NSAttributedString.Key.font: textFont,
      NSAttributedString.Key.foregroundColor: textColor,
      NSAttributedString.Key.paragraphStyle: textStyle,
    ] as [NSAttributedString.Key: Any]

    let textHeight = textFont.lineHeight
    let textY = (size.height - textHeight) / 2
    let textRect = CGRect(x: 0, y: textY,
                          width: size.width, height: textHeight)

    text.draw(in: textRect, withAttributes: textFontAttributes)

    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return newImage
  }
}
