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
	"fmt"
	"io/ioutil"
	"sort"

	"github.com/davidsansome/tsurukame/utils"
)

const (
	scoreThreshold = 0.4
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
	data map[string]entryList
}

func Create() *Index {
	return &Index{
		data: make(map[string]entryList),
	}
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
			if entry.Score > scoreThreshold {
				idx.Add(kanji, entry.Kan, entry.Score)
			}
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

func main() {
	idx := Create()
	utils.Must(idx.AddUnscoredFile("from_keisei.json"))
	utils.Must(idx.AddUnscoredFile("manual.json"))
	utils.Must(idx.AddUnscoredFile("old_script.json"))
	utils.Must(idx.AddScoredFile("stroke_edit_dist.json"))
	utils.Must(idx.AddScoredFile("wk_niai_noto.json"))
	utils.Must(idx.AddScoredFile("yl_radical.json"))
	idx.Sort()

	compact := map[string]string{}
	for k, v := range idx.data {
		var str string
		for _, entry := range v {
			str += entry.Kan
		}
		compact[k] = str
	}

	data, err := json.Marshal(compact)
	utils.Must(err)
	fmt.Println(string(data))
}
