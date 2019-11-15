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
    os_log("MZS - getCurrentTimelineEntry: %{public}@", DataManager.sharedInstance.latestData ?? "nil")

    if let template = templateFor(complication) {
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
    // Call the handler with the timeline entries after to the given date
    handler(nil)
  }

  // MARK: - Placeholder Templates

  func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
    // This method will be called once per supported complication, and the results will be cached
    let template = templateFor(complication)
    os_log("MZS - getLocalizableSampleTemplate: %{public}@", String(describing: template))
    handler(template)
  }

  // MARK: - Internal helpers

  func templateFor(_ complication: CLKComplication) -> CLKComplicationTemplate? {
    // TODO: Get data
    var reviewsPending: Int = 0
    if let data = DataManager.sharedInstance.latestData,
      let reviewCount = data[WatchHelper.KeyReviewCount] as? Int {
      reviewsPending = reviewCount
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
      let template = CLKComplicationTemplateModularSmallSimpleText()
      template.textProvider = CLKTextProvider(format: "%d", reviewsPending)
      return template
    case .modularLarge:
      let template = CLKComplicationTemplateModularLargeTallBody()
      template.headerTextProvider = CLKTextProvider(format: "REVIEWS")
      template.bodyTextProvider = CLKTextProvider(format: "%d", reviewsPending)
      return template
    case .utilitarianSmall:
      fallthrough
    case .utilitarianSmallFlat:
      let template = CLKComplicationTemplateUtilitarianSmallFlat()
      template.textProvider = CLKTextProvider(format: "%d", reviewsPending)
      return template
    case .utilitarianLarge:
      let template = CLKComplicationTemplateUtilitarianLargeFlat()
      // TODO: Pluralize
      template.textProvider = CLKTextProvider(format: "%d REVIEWS", reviewsPending)
      return template
    case .graphicCorner:
      let template = CLKComplicationTemplateGraphicCornerStackText()
      template.outerTextProvider = CLKTextProvider(format: "REVIEWS")
      template.innerTextProvider = CLKTextProvider(format: "%d", reviewsPending)
      return template
    case .graphicCircular:
      let template = CLKComplicationTemplateGraphicCircularClosedGaugeText()
      template.centerTextProvider = CLKTextProvider(format: "%d", reviewsPending)
      template.gaugeProvider = CLKSimpleGaugeProvider(style: .ring, gaugeColor: .red, fillFraction: 1.0)
      return template
    case .graphicBezel:
      let template = CLKComplicationTemplateGraphicBezelCircularText()
      let circularTemplate = CLKComplicationTemplateGraphicCircularStackText()
      // TODO: Pluralize
      circularTemplate.line1TextProvider = CLKSimpleTextProvider(text: "REVIEWS")
      circularTemplate.line2TextProvider = CLKTextProvider(format: "%d", reviewsPending)
      template.circularTemplate = circularTemplate
      // TODO: Pluralize
      //template.textProvider = CLKTextProvider(format: "%d REVIEWS", reviewsPending)
      return template
    case .graphicRectangular:
      let template = CLKComplicationTemplateGraphicRectangularStandardBody()
      template.headerTextProvider = CLKTextProvider(format: "REVIEWS")
      template.body1TextProvider = CLKTextProvider(format: "%d", reviewsPending)
      return template
    @unknown default:
      return nil
    }
    return nil
  }
}
