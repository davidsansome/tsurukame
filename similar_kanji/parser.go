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

package similar_kanji

import (
	"encoding/json"
	"io/ioutil"
	"sort"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/wk/encoding"

	pb "github.com/davidsansome/wk/proto"
)

type entry struct {
	Kan   string  `json:"kan"`
	Score float32 `json:"score"`
}

type entryList []entry

func (a entryList) Len() int           { return len(a) }
func (a entryList) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a entryList) Less(i, j int) bool { return a[i].Score > a[j].Score }

type Index struct {
	kanjiSubjectIDs map[string]int
	data            map[string]entryList
}

func Create(reader encoding.Reader) (*Index, error) {
	idx := &Index{
		kanjiSubjectIDs: make(map[string]int),
		data:            make(map[string]entryList),
	}

	// Index Kanji by ID so we can look them up in the similar kanji file.
	if err := encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		if spb.Kanji != nil {
			idx.kanjiSubjectIDs[spb.GetJapanese()] = int(spb.GetId())
		}
		return nil
	}); err != nil {
		return nil, err
	}
	return idx, nil
}

func (idx *Index) Add(kanji, similarKanji string, score float32) {
	// If we have this similar Kanji already, upgrade its score if the new
	// one is higher, otherwise skip it.
	for existingIdx, existingEntry := range idx.data[kanji] {
		if similarKanji == existingEntry.Kan {
			if score > existingEntry.Score {
				idx.data[kanji][existingIdx].Score = score
			}
			return
		}
	}

	idx.data[kanji] = append(idx.data[kanji], entry{similarKanji, score})
}

func (idx *Index) AddScoredFile(filename string) error {
	b, err := ioutil.ReadFile(filename)
	if err != nil {
		return err
	}
	data := map[string]entryList{}
	if err := json.Unmarshal(b, &data); err != nil {
		return err
	}

	for kanji, entries := range data {
		for _, entry := range entries {
			idx.Add(kanji, entry.Kan, entry.Score)
		}
	}
	return nil
}

func (idx *Index) AddUnscoredFile(filename string) error {
	b, err := ioutil.ReadFile(filename)
	if err != nil {
		return err
	}
	data := map[string][]string{}
	if err := json.Unmarshal(b, &data); err != nil {
		return err
	}

	for kanji, entries := range data {
		for _, entry := range entries {
			idx.Add(kanji, entry, 1.0)
		}
	}
	return nil
}

func (idx *Index) Sort() {
	for kanji, _ := range idx.data {
		sort.Sort(entryList(idx.data[kanji]))
	}
}

func (idx *Index) Lookup(kanji string) []*pb.VisuallySimilarKanji {
	var ret []*pb.VisuallySimilarKanji
	if entries, ok := idx.data[kanji]; ok {
		for _, entry := range entries {
			if id, ok := idx.kanjiSubjectIDs[entry.Kan]; ok {
				ret = append(ret, &pb.VisuallySimilarKanji{
					Id:    proto.Int32(int32(id)),
					Score: proto.Int32(int32(entry.Score * 1000)),
				})
			}
		}
	}
	return ret
}
