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

package markup

import (
	"regexp"

	"github.com/golang/protobuf/proto"

	pb "github.com/davidsansome/tsurukame/proto"
)

var (
	tagRE = regexp.MustCompile(
		`(?U)` +
			`([^\[<]*)` +
			`(?:[\[<]` +
			`(/?(?:vocabulary|reading|ja|jp|kanji|radical|b|em|i|strong|kan|a))` +
			`(?: href="([^"]+)"[^>]*)?` +
			`[\]>])`)
)

func FormatText(completeText string) []*pb.FormattedText {
	var ret []*pb.FormattedText

	matches := tagRE.FindAllStringSubmatchIndex(completeText, -1)
	lastIndex := 0
	var formatStack []pb.FormattedText_Format
	var linkUrlStack []string
	for _, match := range matches {
		lastIndex = match[1]
		text := completeText[match[2]:match[3]]
		nextTag := completeText[match[4]:match[5]]
		var href string
		if match[6] != -1 {
			href = completeText[match[6]:match[7]]
		}

		// Add this text.
		if len(text) != 0 {
			formatStackCopy := make([]pb.FormattedText_Format, len(formatStack))
			copy(formatStackCopy, formatStack)

			formattedText := &pb.FormattedText{Format: formatStackCopy, Text: proto.String(text)}
			if len(linkUrlStack) > 0 {
				formattedText.LinkUrl = proto.String(linkUrlStack[len(linkUrlStack)-1])
			}
			ret = append(ret, formattedText)
		}

		// Add the next format tag.
		if nextTag[0] == '/' {
			lastTag := formatStack[len(formatStack)-1]
			formatStack = formatStack[0 : len(formatStack)-1]
			if lastTag == pb.FormattedText_LINK {
				linkUrlStack = linkUrlStack[0 : len(linkUrlStack)-1]
			}
		} else {
			switch nextTag {
			case "radical":
				formatStack = append(formatStack, pb.FormattedText_RADICAL)
			case "ja", "jp":
				formatStack = append(formatStack, pb.FormattedText_JAPANESE)
			case "reading":
				formatStack = append(formatStack, pb.FormattedText_READING)
			case "vocabulary":
				formatStack = append(formatStack, pb.FormattedText_VOCABULARY)
			case "i":
				formatStack = append(formatStack, pb.FormattedText_ITALIC)
			case "kanji":
				fallthrough
			case "kan":
				formatStack = append(formatStack, pb.FormattedText_KANJI)
			case "b":
				fallthrough
			case "em":
				fallthrough
			case "strong":
				formatStack = append(formatStack, pb.FormattedText_BOLD)
			case "a":
				formatStack = append(formatStack, pb.FormattedText_LINK)
				linkUrlStack = append(linkUrlStack, href)
			}
		}
	}

	// Add the leftover text.
	if lastIndex != len(completeText) {
		leftoverText := completeText[lastIndex:len(completeText)]
		ret = append(ret, &pb.FormattedText{Format: formatStack, Text: proto.String(leftoverText)})
	}

	return ret
}
