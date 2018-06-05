// Copyright 2018 David Sansome
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

package main

import (
	"flag"
	"fmt"
	"strings"

	"github.com/davidsansome/wk/encoding"
	"github.com/davidsansome/wk/utils"

	pb "github.com/davidsansome/wk/proto"
)

func main() {
	flag.Parse()

	if len(flag.Args()) != 1 {
		flag.Usage()
		return
	}

	path := flag.Args()[0]
	reader, err := encoding.Open(path)
	utils.Must(err)

	utils.Must(Lint(reader))
}

func Lint(reader encoding.Reader) error {
	return encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		if spb.Kanji != nil {
			LintText(id, "meaning mnemonic", spb.Kanji.GetMeaningMnemonic())
			LintText(id, "meaning hint", spb.Kanji.GetMeaningHint())
			LintText(id, "reading mnemonic", spb.Kanji.GetReadingMnemonic())
			LintText(id, "reading hint", spb.Kanji.GetReadingHint())
		}
		if spb.Vocabulary != nil {
			LintText(id, "meaning explanation", spb.Vocabulary.GetMeaningExplanation())
			LintText(id, "reading explanation", spb.Vocabulary.GetReadingExplanation())
		}
		return nil
	})
}

func LintText(id int, field, completeText string) {
	text := completeText
	var stack []string
	for {
		pos := strings.Index(text, "[")
		if pos == -1 {
			break
		}

		text = text[pos+1:]
		endPos := strings.Index(text, "]")
		if endPos == -1 {
			ReportError(id, field, completeText, "Missing end bracket")
			break
		}

		tag := text[0:endPos]
		if tag[0] != '/' {
			stack = append(stack, tag)
			continue
		}
		tag = tag[1:]
		if len(stack) == 0 {
			ReportError(id, field, completeText,
				fmt.Sprintf("Closing tag [/%s] without opening tag", tag))
			break
		}
		topTag := stack[len(stack)-1]
		stack = stack[0 : len(stack)-1]
		if tag != topTag {
			ReportError(id, field, completeText,
				fmt.Sprintf("Mismatching closing tag [/%s] for opening tag [%s]", tag, topTag))
			break
		}
	}
}

func ReportError(id int, field, completeText, reason string) {
	lines := strings.Split(completeText, "\n")
	completeText = strings.Join(lines, "\n  ")
	fmt.Printf("%d %s\n%s\n  %s\n\n", id, field, reason, completeText)
}
