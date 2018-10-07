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

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/tsurukame/encoding"
	"github.com/davidsansome/tsurukame/utils"

	pb "github.com/davidsansome/tsurukame/proto"
)

var (
	outputProto = flag.Bool("output-proto", false, "Output a overrides text proto")
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
	overrides := []*pb.Subject{}

	encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		override := &pb.Subject{}
		override.Kanji = &pb.Kanji{}
		override.Vocabulary = &pb.Vocabulary{}

		if spb.Kanji != nil {
			if !LintText(id, "meaning mnemonic", spb.Kanji.GetMeaningMnemonic()) {
				override.Kanji.MeaningMnemonic = spb.Kanji.MeaningMnemonic
			}
			if !LintText(id, "meaning hint", spb.Kanji.GetMeaningHint()) {
				override.Kanji.MeaningHint = spb.Kanji.MeaningHint
			}
			if !LintText(id, "reading mnemonic", spb.Kanji.GetReadingMnemonic()) {
				override.Kanji.ReadingMnemonic = spb.Kanji.ReadingMnemonic
			}
			if !LintText(id, "reading hint", spb.Kanji.GetReadingHint()) {
				override.Kanji.ReadingHint = spb.Kanji.ReadingHint
			}
		}
		if spb.Vocabulary != nil {
			if !LintText(id, "meaning explanation", spb.Vocabulary.GetMeaningExplanation()) {
				override.Vocabulary.MeaningExplanation = spb.Vocabulary.MeaningExplanation
			}
			if !LintText(id, "reading explanation", spb.Vocabulary.GetReadingExplanation()) {
				override.Vocabulary.ReadingExplanation = spb.Vocabulary.ReadingExplanation
			}
		}

		if proto.Size(override.Kanji) == 0 {
			override.Kanji = nil
		}
		if proto.Size(override.Vocabulary) == 0 {
			override.Vocabulary = nil
		}
		if proto.Size(override) != 0 {
			override.Id = spb.Id
			overrides = append(overrides, override)
		}

		return nil
	})

	if *outputProto {
		overridesProto := pb.SubjectOverrides{}
		overridesProto.Subject = overrides
		fmt.Println(proto.MarshalTextString(&overridesProto))
	}
	return nil
}

func LintText(id int, field, completeText string) bool {
	text := completeText
	var stack []string
	for {
		pos := strings.Index(text, "[")
		if pos == -1 {
			return true
		}

		text = text[pos+1:]
		endPos := strings.Index(text, "]")
		if endPos == -1 {
			ReportError(id, field, completeText, "Missing end bracket")
			return false
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
			return false
		}
		topTag := stack[len(stack)-1]
		stack = stack[0 : len(stack)-1]
		if tag != topTag {
			ReportError(id, field, completeText,
				fmt.Sprintf("Mismatching closing tag [/%s] for opening tag [%s]", tag, topTag))
			return false
		}
	}
	return true
}

func ReportError(id int, field, completeText, reason string) {
	if *outputProto {
		return
	}
	lines := strings.Split(completeText, "\n")
	completeText = strings.Join(lines, "\n  ")
	fmt.Printf("%d %s\n%s\n  %s\n\n", id, field, reason, completeText)
}
