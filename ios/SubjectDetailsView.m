#import "SubjectDetailsView.h"
#import "SubjectDetailsViewController.h"
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
     "span.related.kanji {"
     "  background-color: #f0a;"
     "}"
     "span.related.radical {"
     "  background-color: #0af;"
     "}"
     "span.related {"
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
     "</style>";

static NSRegularExpression *kHighlightRE;
static NSRegularExpression *kJaSpanRE;

@implementation WKSubjectDetailsView

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
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
  
  self = [super initWithCoder:coder];
  if (self) {
    self.navigationDelegate = self;
  }
  return self;
}

- (NSString *)renderSubjectDetails:(WKSubject *)subject {
  NSMutableString *ret = [NSMutableString stringWithString:kHeader];
  
  if (subject.hasRadical) {
    [self addTextSectionTo:ret title:@"Meaning" content:subject.commaSeparatedMeanings];
    [self addTextSectionTo:ret title:@"Mnemonic" content:[self highlightText:subject.radical.mnemonic]];
  }
  if (subject.hasKanji) {
    [self addTextSectionTo:ret title:@"Meaning" content:subject.commaSeparatedMeanings];
    [self addTextSectionTo:ret title:@"Reading" content:subject.commaSeparatedReadings];  // TODO: primary readings only.
    [self addTextSectionTo:ret title:@"Related Kanji" content:[self renderComponents:subject.componentSubjectIdsArray]];
    [self addTextSectionTo:ret title:@"Meaning Explanation" content:[self highlightText:subject.kanji.meaningMnemonic]];
    [self addTextSectionTo:ret title:@"Reading Explanation" content:[self highlightText:subject.kanji.readingMnemonic]];
    // TODO: context
  }
  if (subject.hasVocabulary) {
    [self addTextSectionTo:ret title:@"Meaning" content:subject.commaSeparatedMeanings];
    [self addTextSectionTo:ret title:@"Reading" content:subject.commaSeparatedReadings];
    [self addTextSectionTo:ret title:@"Part of Speech" content:subject.vocabulary.commaSeparatedPartsOfSpeech];
    [self addTextSectionTo:ret title:@"Related Kanji" content:[self renderComponents:subject.componentSubjectIdsArray]];
    [self addTextSectionTo:ret title:@"Meaning Explanation" content:[self highlightText:subject.vocabulary.meaningExplanation]];
    [self addTextSectionTo:ret title:@"Reading Explanation" content:[self highlightText:subject.vocabulary.readingExplanation]];
    // TODO: context
  }
  
  return ret;
}

- (void)addTextSectionTo:(NSMutableString *)ret
                   title:(NSString *)title
                 content:(NSString *)content {
  [ret appendFormat:@"<div><h1>%@</h1>%@</div>", title, content];
}

- (NSString *)highlightText:(NSString *)text {
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
    
    [ret appendFormat:@"<li><a href=\"wk://subject/%d\"><span class=\"related %@\">%@</span>%@</a></li>",
     subjectID, class, subject.japanese, subject.primaryMeaning];
  }
  [ret appendString:@"</ul>"];
  return ret;
}

#pragma mark - Setters

- (void)setSubject:(WKSubject *)subject {
  [self loadHTMLString:[self renderSubjectDetails:subject] baseURL:nil];
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
    [self.linkHandler openSubject:_lastSubjectClicked];
  }
  decisionHandler(WKNavigationActionPolicyCancel);
}

@end

NS_ASSUME_NONNULL_END

