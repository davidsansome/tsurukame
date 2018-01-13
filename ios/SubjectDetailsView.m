#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
#import "UIColor+HexString.h"
#import "proto/Wanikani+Convenience.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *kHeader =
    @"<meta name=\"viewport\" content=\"user-scalable=no, width=device-width\">"
     "<style>"
     "body {"
     "  font-family: sans-serif;"
     "  font-size: 14px;"
     "}"
     "h1 {"
     "  margin: 0 0 0.2em;"
     "  padding-bottom: 0.2em;"
     "  color: #888888;"
     "  font-size: 1em;"
     "  font-weight: normal;"
     "  letter-spacing: -1px;"
     "  line-height: 1em;"
     "  border-bottom: 1px solid #eee;"
     "  box-shadow: 1px 10px 9px -6px rgba(0,0,0,0.025);"
     "}"
     "div {"
     "  margin-bottom: 20px;"
     "}"
     "span.highlight {"
     "  padding: 0 0.3em 0.15px;"
     "  text-shadow: 0 1px 0 rgba(255,255,255,0.5);"
     "  white-space: nowrap;"
     "  border-radius: 3px;"
     "}"
     "span.kanji {"
     "  background-color: #ffd6f1;"
     "}"
     "span.radical {"
     "  background-color: #d6f1ff;"
     "}"
     "span.vocabulary {"
     "  background-color: #f1d6ff;"
     "}"
     "span.reading {"
     "  background-color: #555;"
     "  color: #fff;"
     "  text-shadow: 0 1px 0 #000;"
     "}"
     "span.meaning {"
     "  background-color: #eee;"
     "}"
     ".related.kanji {"
     "  background-color: #f0a;"
     "}"
     ".related.radical {"
     "  background-color: #0af;"
     "}"
     ".related {"
     "  display: inline-block;"
     "  margin-right: 0.3em;"
     "  width: 1.8em;"
     "  height: 1.8em;"
     "  color: #fff;"
     "  line-height: 1.7em;"
     "  text-align: center;"
     "  text-shadow: 0 1px 0 rgba(0,0,0,0.3);"
     "  box-sizing: border-box;"
     "  border-radius: 3px;"
     "  box-shadow: 0 -3px 0 rgba(0,0,0,0.2) inset,0 0 10px rgba(255,255,255,0.5)"
     "}"
     "img.related.radical {"
     "  vertical-align: middle;"
     "  padding: 0.4em;"
     "}"
     "ul {"
     "  margin: 0;"
     "  padding: 0;"
     "}"
     "li {"
     "  display: inline-block;"
     "}"
     "li:after {"
     "  content: \"+\";"
     "  margin: 0 0.8em;"
     "  color: #d5d5d5;"
     "  font-weight: bold;"
     "}"
     "li:last-child:after {"
     "  content: none;"
     "}"
     "a {"
     "  text-decoration: none;"
     "  color: black;"
     "}"
     "span.pri { font-weight: normal; }"
     "span.alt { font-weight: lighter; }"
     "span.user { color: #3B99FC; }"
     "</style>";

@implementation WKSubjectDetailsView

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    self.navigationDelegate = self;
  }
  return self;
}

#pragma mark - Rendering

- (NSString *)renderSubjectDetails:(WKSubject *)subject
                    studyMaterials:(WKStudyMaterials *)studyMaterials {
  NSMutableString *ret = [NSMutableString stringWithString:kHeader];
  if (subject.hasRadical) {
    [self addTextSectionTo:ret title:@"Meaning" content:[self renderMeanings:subject.meaningsArray studyMaterials:studyMaterials]];
    [self addTextSectionTo:ret title:@"Mnemonic" content:[self highlightText:subject.radical.mnemonic]];
  }
  if (subject.hasKanji) {
    [self addTextSectionTo:ret title:@"Meaning" content:[self renderMeanings:subject.meaningsArray studyMaterials:studyMaterials]];
    [self addTextSectionTo:ret title:@"Reading" content:[self renderReadings:subject.readingsArray]];
    [self addTextSectionTo:ret title:@"Radicals" content:[self renderComponents:subject.componentSubjectIdsArray]];
    [self addTextSectionTo:ret title:@"Meaning Explanation" content:[self highlightText:subject.kanji.meaningMnemonic]];
    [self addTextSectionTo:ret title:@"Reading Explanation" content:[self highlightText:subject.kanji.readingMnemonic]];
    // TODO: context
  }
  if (subject.hasVocabulary) {
    [self addTextSectionTo:ret title:@"Meaning" content:[self renderMeanings:subject.meaningsArray studyMaterials:studyMaterials]];
    [self addTextSectionTo:ret title:@"Reading" content:[self renderReadings:subject.readingsArray]];
    [self addTextSectionTo:ret title:@"Kanji" content:[self renderComponents:subject.componentSubjectIdsArray]];
    [self addTextSectionTo:ret title:@"Meaning Explanation" content:[self highlightText:subject.vocabulary.meaningExplanation]];
    [self addTextSectionTo:ret title:@"Reading Explanation" content:[self highlightText:subject.vocabulary.readingExplanation]];
    [self addTextSectionTo:ret title:@"Part of Speech" content:subject.vocabulary.commaSeparatedPartsOfSpeech];
    // TODO: context
  }
  
  return ret;
}

- (NSString *)renderMeanings:(NSArray<WKMeaning *> *)meanings
              studyMaterials:(WKStudyMaterials *)studyMaterials {
  NSMutableArray<NSString *> *ret = [NSMutableArray array];
  for (WKMeaning *meaning in meanings) {
    if (meaning.isPrimary) {
      [ret addObject:[NSString stringWithFormat:@"<span class=\"pri\">%@</span>", meaning.meaning]];
    }
  }
  for (NSString *meaning in studyMaterials.meaningSynonymsArray) {
    [ret addObject:[NSString stringWithFormat:@"<span class=\"user\">%@</span>", meaning]];
  }
  for (WKMeaning *meaning in meanings) {
    if (!meaning.isPrimary) {
      [ret addObject:[NSString stringWithFormat:@"<span class=\"alt\">%@</span>", meaning.meaning]];
    }
  }
  return [ret componentsJoinedByString:@", "];
}

- (NSString *)renderReadings:(NSArray<WKReading *> *)readings {
  NSMutableArray<NSString *> *ret = [NSMutableArray array];
  for (WKReading *reading in readings) {
    if (reading.isPrimary) {
      [ret addObject:[NSString stringWithFormat:@"<span class=\"pri\">%@</span>", reading.reading]];
    } else {
      [ret addObject:[NSString stringWithFormat:@"<span class=\"alt\">%@</span>", reading.reading]];
    }
  }
  return [ret componentsJoinedByString:@", "];
}

- (void)addTextSectionTo:(NSMutableString *)ret
                   title:(NSString *)title
                 content:(NSString *)content {
  [ret appendFormat:@"<div><h1>%@</h1>%@</div>", title, content];
}

- (NSString *)highlightText:(NSString *)text {
  static NSRegularExpression *kHighlightRE;
  static NSRegularExpression *kJaSpanRE;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kHighlightRE = [NSRegularExpression regularExpressionWithPattern:
                    @"\\[(kanji|radical|vocabulary|reading|meaning)\\]"
                    "([^\\[]+)"
                    "\\[\\/[^\\]]+\\]" options:0 error:nil];
    kJaSpanRE = [NSRegularExpression regularExpressionWithPattern:
                 @"\\[ja\\]"
                 "([^\\[]+)"
                 "\\[\\/[^\\]]+\\]" options:0 error:nil];
  });

  NSMutableString *ret = [NSMutableString stringWithString:text];
  [kJaSpanRE replaceMatchesInString:ret
                            options:0
                              range:NSMakeRange(0, ret.length)
                       withTemplate:@"$1"];
  [kHighlightRE replaceMatchesInString:ret
                               options:0
                                 range:NSMakeRange(0, ret.length)
                          withTemplate:@"<span class=\"highlight $1\">$2</span>"];
  return ret;
}

- (NSString *)renderComponents:(GPBInt32Array *)components {
  NSMutableString *ret = [NSMutableString string];
  [ret appendString:@"<ul>"];
  for (int i = 0; i < components.count; ++i) {
    int subjectID = [components valueAtIndex:i];
    WKSubject *subject = [_dataLoader loadSubject:subjectID];
    if (!subject) {
      continue;
    }
    
    NSString *class;
    if (subject.hasKanji) {
      class = @"kanji";
    } else if (subject.hasRadical) {
      class = @"radical";
    } else {
      continue;
    }
    
    if (!subject.hasRadical || !subject.radical.hasCharacterImageFile) {
      [ret appendFormat:@"<li><a href=\"wk://subject/%d\"><span class=\"related %@\">%@</span>%@</a></li>",
       subjectID, class, subject.japanese, subject.primaryMeaning];
    } else {
      UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"radical-%d", subject.id_p]];
      NSString *base64 = [UIImagePNGRepresentation(image) base64EncodedStringWithOptions:0];
      [ret appendFormat:@"<li><a href=\"wk://subject/%d\"><img class=\"related %@\" src=\"data:image/png;base64, %@\" />%@</a></li>",
       subjectID, class, base64, subject.primaryMeaning];
    }
  }
  [ret appendString:@"</ul>"];
  return ret;
}

#pragma mark - Setters

- (void)updateWithSubject:(WKSubject *)subject studyMaterials:(WKStudyMaterials *)studyMaterials {
  [self loadHTMLString:[self renderSubjectDetails:subject studyMaterials:studyMaterials]
               baseURL:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  NSURL *url = navigationAction.request.URL;
  if (![url.scheme isEqualToString:@"wk"]) {
    decisionHandler(WKNavigationActionPolicyAllow);
    return;
  }
  
  if ([url.host isEqualToString:@"subject"]) {
    int subjectID = [[url.path substringFromIndex:1] intValue];
    _lastSubjectClicked = [_dataLoader loadSubject:subjectID];
    if ([self.delegate respondsToSelector:@selector(openSubject:)]) {
      [self.delegate openSubject:_lastSubjectClicked];
    }
  }
  decisionHandler(WKNavigationActionPolicyCancel);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
  if ([self.delegate respondsToSelector:@selector(subjectDetailsView:didFinishNavigation:)]) {
    [self.delegate subjectDetailsView:self didFinishNavigation:navigation];
  }
}

@end

NS_ASSUME_NONNULL_END

