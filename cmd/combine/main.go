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
	"encoding/binary"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/wk/fileencoding"
	pb "github.com/davidsansome/wk/proto"
	"github.com/davidsansome/wk/utils"
)

var (
	out = flag.String("out", "data.bin", "Output file")

	order = binary.LittleEndian
)

func main() {
	flag.Parse()
	utils.Must(Combine())
}

func Combine() error {
	// List files.
	files, err := fileencoding.ListFilenames()
	if err != nil {
		return err
	}

	// Read everything into memory.
	all := make([][]byte, len(files))
	for _, f := range files {
		spb, err := fileencoding.ReadSubjectByFilename(f)
		if err != nil {
			return err
		}

		// Remove fields we don't care about for the iOS app.
		id := spb.GetId()
		spb.DocumentUrl = nil
		spb.Id = nil
		if spb.Radical != nil && spb.Radical.CharacterImage != nil {
			spb.Radical.CharacterImage = nil
			spb.Radical.HasCharacterImageFile = proto.Bool(true)
		}

		// Clean up the data.
		if err := ReorderComponentSubjectIDs(spb); err != nil {
			return err
		}
		UnsetEmptyFields(spb)

		data, err := proto.Marshal(spb)
		if err != nil {
			return err
		}

		// Make space in the array for this ID.
		for len(all) <= int(id) {
			all = append(all, nil)
		}
		all[id] = data
	}

	fh, err := os.Create(*out)
	if err != nil {
		return err
	}
	defer fh.Close()

	// Write the index.
	binary.Write(fh, order, uint32(len(all)))
	offset := 4 + 4*len(all)
	for _, d := range all {
		binary.Write(fh, order, uint32(offset))
		offset += len(d)
	}

	// Write each encoded protobuf.
	for _, d := range all {
		fh.Write(d)
	}

	return nil
}

func ReorderComponentSubjectIDs(spb *pb.Subject) error {
	if spb.Vocabulary == nil {
		return nil
	}

	characterToID := map[string]int32{}
	for _, id := range spb.ComponentSubjectIds {
		pb, err := fileencoding.ReadSubjectByID(id)
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
			spb.GetJapanese(), spb.ComponentSubjectIds, newComponentIDs)
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
