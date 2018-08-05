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
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"strings"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/wk/encoding"
	"github.com/davidsansome/wk/markup"
	"github.com/davidsansome/wk/utils"

	pb "github.com/davidsansome/wk/proto"
)

var (
	inputDir         = flag.String("in", "data", "Input directory")
	outputFile       = flag.String("out", "data.bin", "Output file")
	overridesFile    = flag.String("overrides", "overrides.txt", "Overrides text proto")
	similarKanjiFile = flag.String("similar-kanji-file", "wk_niai_noto.json", "Similar kanji input")
)

func main() {
	flag.Parse()
	utils.Must(Combine())
}

func Combine() error {
	reader, err := encoding.OpenDirectory(*inputDir)
	utils.Must(err)

	writer, err := encoding.OpenFileWriter(*outputFile)
	utils.Must(err)

	overrides := map[int]*pb.Subject{}
	if len(*overridesFile) != 0 {
		data, err := ioutil.ReadFile(*overridesFile)
		if err != nil {
			fmt.Printf("Error opening %s: %s\n", *overridesFile, err)
		} else {
			var overridesProto pb.SubjectOverrides
			utils.Must(proto.UnmarshalText(string(data), &overridesProto))
			for _, overrideProto := range overridesProto.Subject {
				overrides[int(overrideProto.GetId())] = overrideProto
			}
		}
	}

	sk, err := IndexSimilarKanji(reader, *similarKanjiFile)
	utils.Must(err)

	utils.Must(encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		// Remove fields we don't care about for the iOS app.
		spb.DocumentUrl = nil
		if spb.Radical != nil && spb.Radical.CharacterImage != nil {
			spb.Radical.CharacterImage = nil
			if spb.GetJapanese() == "" {
				spb.Radical.HasCharacterImageFile = proto.Bool(true)
			}
		}
		if spb.Vocabulary != nil {
			spb.Vocabulary.Audio = nil
		}

		// Clean up the data.
		if err := ReorderComponentSubjectIDs(reader, spb); err != nil {
			return err
		}
		UnsetEmptyFields(spb)

		// Override fields.
		if override, ok := overrides[id]; ok {
			proto.Merge(spb, override)
		}

		// Format the markup.
		if spb.Radical != nil {
			spb.Radical.FormattedMnemonic = markup.FormatText(spb.Radical.GetMnemonic())
			spb.Radical.Mnemonic = nil
		}
		if spb.Kanji != nil {
			spb.Kanji.FormattedMeaningMnemonic = markup.FormatText(spb.Kanji.GetMeaningMnemonic())
			spb.Kanji.FormattedMeaningHint = markup.FormatText(spb.Kanji.GetMeaningHint())
			spb.Kanji.FormattedReadingMnemonic = markup.FormatText(spb.Kanji.GetReadingMnemonic())
			spb.Kanji.FormattedReadingHint = markup.FormatText(spb.Kanji.GetReadingHint())
			spb.Kanji.MeaningMnemonic = nil
			spb.Kanji.MeaningHint = nil
			spb.Kanji.ReadingMnemonic = nil
			spb.Kanji.ReadingHint = nil
		}
		if spb.Vocabulary != nil {
			spb.Vocabulary.FormattedMeaningExplanation = markup.FormatText(spb.Vocabulary.GetMeaningExplanation())
			spb.Vocabulary.FormattedReadingExplanation = markup.FormatText(spb.Vocabulary.GetReadingExplanation())
			spb.Vocabulary.MeaningExplanation = nil
			spb.Vocabulary.ReadingExplanation = nil
		}

		// Add similar kanji.
		if spb.Kanji != nil {
			spb.Kanji.VisuallySimilarKanji = sk.Convert(spb.GetJapanese())
		}

		return writer.WriteSubject(id, spb)
	}))

	return writer.Close()
}

func ReorderComponentSubjectIDs(reader encoding.Reader, spb *pb.Subject) error {
	if spb.Vocabulary == nil {
		return nil
	}

	characterToID := map[string]int32{}
	for _, id := range spb.ComponentSubjectIds {
		pb, err := reader.ReadSubject(int(id))
		if err != nil {
			return err
		}
		characterToID[pb.GetJapanese()] = id
	}

	var newComponentIDs []int32
	seenComponentIDs := map[int32]struct{}{}
	for _, char := range spb.GetJapanese() {
		if id, ok := characterToID[string(char)]; ok {
			if _, ok := seenComponentIDs[id]; ok {
				continue
			}
			newComponentIDs = append(newComponentIDs, id)
			seenComponentIDs[id] = struct{}{}
		}
	}

	if len(newComponentIDs) != len(spb.ComponentSubjectIds) {
		return fmt.Errorf("different length component subject ID lists for %s: %v vs. %v",
			spb, spb.ComponentSubjectIds, newComponentIDs)
	}

	spb.ComponentSubjectIds = newComponentIDs
	return nil
}

func UnsetEmptyFields(spb *pb.Subject) {
	if spb.Kanji != nil {
		if len(strings.TrimSpace(spb.Kanji.GetMeaningHint())) == 0 {
			spb.Kanji.MeaningHint = nil
		}
		if len(strings.TrimSpace(spb.Kanji.GetReadingHint())) == 0 {
			spb.Kanji.ReadingHint = nil
		}
	}
}

type similarKanjiEntry struct {
	Kan   string  `json:"kan"`
	Score float32 `json:"score"`
}

type similarKanji struct {
	kanjiSubjectIDs map[string]int
	data            map[string][]similarKanjiEntry
}

func IndexSimilarKanji(reader encoding.Reader, filename string) (*similarKanji, error) {
	r := &similarKanji{
		kanjiSubjectIDs: make(map[string]int),
		data:            make(map[string][]similarKanjiEntry),
	}

	// Index Kanji by ID so we can look them up in the similar kanji file.
	if err := encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		if spb.Kanji != nil {
			r.kanjiSubjectIDs[spb.GetJapanese()] = int(spb.GetId())
		}
		return nil
	}); err != nil {
		return nil, err
	}

	// Read the similar Kanji file.
	similarKanjiData, err := ioutil.ReadFile(*similarKanjiFile)
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(similarKanjiData, &r.data); err != nil {
		return nil, err
	}
	return r, nil
}

func (s *similarKanji) Convert(kanji string) []*pb.VisuallySimilarKanji {
	var ret []*pb.VisuallySimilarKanji
	if entries, ok := s.data[kanji]; ok {
		for _, entry := range entries {
			if id, ok := s.kanjiSubjectIDs[entry.Kan]; ok {
				ret = append(ret, &pb.VisuallySimilarKanji{
					Id:    proto.Int32(int32(id)),
					Score: proto.Int32(int32(entry.Score * 1000)),
				})
			}
		}
	}
	return ret
}
