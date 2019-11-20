// Copyright 2019 David Sansome
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
  // MARK: - Timeline Configuration

  func getSupportedTimeTravelDirections(for _: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
    handler([])
  }

  func getTimelineStartDate(for _: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
    handler(nil)
  }

  func getTimelineEndDate(for _: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
    handler(nil)
  }

  func getPrivacyBehavior(for _: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
    handler(.showOnLockScreen)
  }

  // MARK: - Timeline Population

  func getCurrentTimelineEntry(for complication: CLKComplication,
                               withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
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

  func getTimelineEntries(for _: CLKComplication, after _: Date, limit _: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
    // TODO: Transfer upcoming review info so we can handle offline complication refreshes.
    // Call the handler with the timeline entries after to the given date
    handler(nil)
  }

  // MARK: - Placeholder Templates

  func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
    // This method will be called once per supported complication, and the results will be cached
    // TODO: More complete example data
    let template = templateFor(complication,
                               userData: DataManager.sharedInstance.latestData ?? [
                                 WatchHelper.KeyReviewCount: 22,
                                 WatchHelper.KeyReviewNextHourCount: 5,
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
      if let nextReviewAt = data[WatchHelper.KeyNextReviewAt] as? Int {
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
      let circularTemplate = CLKComplicationTemplateGraphicCircularStackText()
      circularTemplate.line1TextProvider = CLKTextProvider(format: "%d NOW", reviewsPending)
      if nextHour > 0 || nextReview == nil {
        circularTemplate.line2TextProvider = CLKTextProvider(format: "%d next hour", nextHour)
      } else {
        circularTemplate.line2TextProvider = relativeDateProvider(date: nextReview!)
      }
      template.circularTemplate = circularTemplate
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
    // TODO: implement level data complications
    let currentLevel = userData?[WatchHelper.KeyLevelCurrent] as? Int ?? 0
    let learned = userData?[WatchHelper.KeyLevelLearned] as? Int ?? 0
    let total = userData?[WatchHelper.KeyLevelTotal] as? Int ?? 0
    let halfLevel = userData?[WatchHelper.KeyLevelHalf] as? Bool ?? false
    let fillFraction = Float(learned) / Float(total)

    let levelTextProvider: CLKTextProvider
    if halfLevel {
      levelTextProvider = CLKTextProvider(format: "Level %.1f", Float(currentLevel) + 0.5)
    } else {
      levelTextProvider = CLKTextProvider(format: "Level %d", currentLevel)
    }

    switch complication.family {
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
    case .graphicCircular:
      let template = CLKComplicationTemplateGraphicCircularOpenGaugeRangeText()
      template.centerTextProvider = CLKTextProvider(format: "%d", learned)
      template.gaugeProvider = CLKSimpleGaugeProvider(style: .ring, gaugeColor: .red, fillFraction: fillFraction)
      template.leadingTextProvider = CLKSimpleTextProvider(text: "0")
      template.trailingTextProvider = CLKTextProvider(format: "%d", total)
      return template
    case .graphicRectangular:
      let template = CLKComplicationTemplateGraphicRectangularTextGauge()
      template.headerTextProvider = levelTextProvider
      template.body1TextProvider = CLKTextProvider(format: "%d of %d learned", learned, total)
      if let img = UIImage(named: "miniCrab") {
        template.headerImageProvider = CLKFullColorImageProvider(fullColorImage: img)
      }
      template.gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .red, fillFraction: fillFraction)
      return template
    default:
      return nil
    }
  }

  func relativeDateProvider(date: Date) -> CLKRelativeDateTextProvider {
    let unit: NSCalendar.Unit
    let timeInterval = Date().distance(to: date)
    if timeInterval >= 86400 {
      unit = .day
    } else if timeInterval >= 3600 {
      unit = .hour
    } else {
      unit = .minute
    }
    return CLKRelativeDateTextProvider(date: date, style: .offsetShort, units: unit)
  }
}
