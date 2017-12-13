#import "SubjectDetailsRenderer.h"
#import "proto/Wanikani+Convenience.h"

static const NSString *kHeader =
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
     "  -webkit-box-shadow: 1px 10px 9px -6px rgba(0,0,0,0.025);"
     "  -moz-box-shadow: 1px 10px 9px -6px rgba(0,0,0,0.025);"
     "  box-shadow: 1px 10px 9px -6px rgba(0,0,0,0.025);"
     "}"
     "div {"
     "  margin-bottom: 20px;"
     "}"
     "span.highlight {"
     "  padding: 0 0.3em 0.15px;"
     "  text-shadow: 0 1px 0 rgba(255,255,255,0.5);"
     "  white-space: nowrap;"
     "  -webkit-border-radius: 3px;"
     "  -moz-border-radius: 3px;"
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
     "</style>";

static NSRegularExpression *kHighlightRE;
static NSRegularExpression *kJaSpanRE;

static void AddTextSection(NSMutableString *ret, NSString *title, NSString *content) {
  [ret appendFormat:@"<div><h1>%@</h1>%@</div>", title, content];
}

static NSString *HighlightText(NSString *text) {
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

NSString *WKRenderSubjectDetails(WKSubject *subject) {
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
  
  NSMutableString *ret = [NSMutableString stringWithString:kHeader];

  if (subject.hasRadical) {
    AddTextSection(ret, @"Meaning", subject.radical.commaSeparatedMeanings);
    AddTextSection(ret, @"Mnemonic", HighlightText(subject.radical.mnemonic));
  }
  if (subject.hasKanji) {
    AddTextSection(ret, @"Meaning", subject.kanji.commaSeparatedMeanings);
    AddTextSection(ret, @"Reading", subject.kanji.commaSeparatedReadings);  // TODO: primary readings only.
    // TODO: radical combinations
    AddTextSection(ret, @"Meaning Explanation", HighlightText(subject.kanji.meaningMnemonic));
    AddTextSection(ret, @"Reading Explanation", HighlightText(subject.kanji.readingMnemonic));
    // TODO: context
  }
  if (subject.hasVocabulary) {
    AddTextSection(ret, @"Meaning", subject.vocabulary.commaSeparatedMeanings);
    AddTextSection(ret, @"Reading", subject.vocabulary.commaSeparatedReadings);
    AddTextSection(ret, @"Part of Speech", subject.vocabulary.commaSeparatedPartsOfSpeech);
    // TODO: related kanji
    AddTextSection(ret, @"Meaning Explanation", HighlightText(subject.vocabulary.meaningExplanation));
    AddTextSection(ret, @"Reading Explanation", HighlightText(subject.vocabulary.readingExplanation));
    // TODO: context
  }
  
  return ret;
}
