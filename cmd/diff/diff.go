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

	"github.com/golang/protobuf/proto"
	"github.com/sergi/go-diff/diffmatchpatch"

	"github.com/davidsansome/wk/encoding"
	"github.com/davidsansome/wk/utils"
)

func main() {
	flag.Parse()

	if len(flag.Args()) != 2 {
		flag.Usage()
		return
	}

	a, err := encoding.Open(flag.Args()[0])
	utils.Must(err)
	b, err := encoding.Open(flag.Args()[1])
	utils.Must(err)

	utils.Must(Diff(a, b))
}

func Diff(a, b encoding.Reader) error {
	aCount, err := a.SubjectCount()
	if err != nil {
		return err
	}

	bCount, err := b.SubjectCount()
	if err != nil {
		return err
	}

	dmp := diffmatchpatch.New()
	for i := 0; i < aCount && i < bCount; i++ {
		var astr, bstr string
		if spb, err := a.ReadSubject(i); err == nil {
			astr = proto.MarshalTextString(spb)
		}
		if spb, err := b.ReadSubject(i); err == nil {
			bstr = proto.MarshalTextString(spb)
		}

		diffs := dmp.DiffMain(astr, bstr, false)
		if AreAllDiffsEqual(diffs) {
			continue
		}
		fmt.Printf("\n===== %d =====\n\n", i)
		fmt.Println(dmp.DiffPrettyText(diffs))
	}
	return nil
}

func AreAllDiffsEqual(diffs []diffmatchpatch.Diff) bool {
	for _, diff := range diffs {
		if diff.Type != diffmatchpatch.DiffEqual {
			return false
		}
	}
	return true
}
