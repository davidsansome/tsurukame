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
	"io/ioutil"
	"sort"
	"strings"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/tsurukame/encoding"
	"github.com/davidsansome/tsurukame/markup"
	"github.com/davidsansome/tsurukame/similar_kanji"
	"github.com/davidsansome/tsurukame/utils"

	pb "github.com/davidsansome/tsurukame/proto"
)

var (
	inputDir      = flag.String("in", "data", "Input directory")
	outputFile    = flag.String("out", "data.bin", "Output file")
	overridesFile = flag.String("overrides", "overrides.txt", "Overrides text proto")
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

	sk, err := similar_kanji.Create(reader)
	utils.Must(err)
	utils.Must(sk.AddUnscoredFile("similar_kanji/from_keisei.json"))
	utils.Must(sk.AddUnscoredFile("similar_kanji/manual.json"))
	utils.Must(sk.AddUnscoredFile("similar_kanji/old_script.json"))
	utils.Must(sk.AddScoredFile("similar_kanji/stroke_edit_dist.json"))
	utils.Must(sk.AddScoredFile("similar_kanji/wk_niai_noto.json"))
	utils.Must(sk.AddScoredFile("similar_kanji/yl_radical.json"))
	sk.Sort()

	utils.Must(encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		// Check all the dependent subjects are present.
		for _, sid := range spb.ComponentSubjectIds {
			if !reader.HasSubject(int(sid)) {
				return fmt.Errorf("missing subject %d (component of %d)", sid, id)
			}
		}
		for _, sid := range spb.AmalgamationSubjectIds {
			if !reader.HasSubject(int(sid)) {
				return fmt.Errorf("missing subject %d (amalgamation of %d)", sid, id)
			}
		}
		if spb.Kanji != nil {
			for _, vsk := range spb.Kanji.VisuallySimilarKanji {
				if !reader.HasSubject(int(vsk.GetId())) {
					return fmt.Errorf("missing subject %d (similar kanji of %d)", vsk.GetId(), id)
				}
			}
		}

		// Remove fields we don't care about for the iOS app.
		spb.DocumentUrl = nil
		if spb.Radical != nil && spb.Radical.CharacterImage != nil {
			spb.Radical.CharacterImage = nil
			if spb.GetJapanese() == "" {
				spb.Radical.HasCharacterImageFile = proto.Bool(true)
			}
		}

		// Clean up the data.
		if err := ReorderComponentSubjectIDs(reader, spb); err != nil {
			return err
		}
		SortSubjectIDsByLevel(reader, spb.AmalgamationSubjectIds)
		UnsetEmptyFields(spb)

		// Override fields.
		if override, ok := overrides[id]; ok {
			proto.Merge(spb, override)
		}

		// Format the markup.
		if spb.Radical != nil {
			spb.Radical.FormattedMnemonic = markup.FormatText(spb.Radical.GetMnemonic())
			spb.Radical.Mnemonic = nil
			if spb.Radical.DeprecatedMnemonic != nil {
				spb.Radical.FormattedDeprecatedMnemonic = markup.FormatText(spb.Radical.GetDeprecatedMnemonic())
				spb.Radical.DeprecatedMnemonic = nil
			}
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
			spb.Kanji.VisuallySimilarKanji = sk.Lookup(spb.GetJapanese())
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

func SortSubjectIDsByLevel(reader encoding.Reader, subjectIDs []int32) {
	sort.Slice(subjectIDs, func(i, j int) bool {
		iPb, err := reader.ReadSubject(int(subjectIDs[i]))
		if err != nil {
			return false
		}
		jPb, err := reader.ReadSubject(int(subjectIDs[j]))
		if err != nil {
			return false
		}
		return iPb.GetLevel() < jPb.GetLevel()
	})
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
