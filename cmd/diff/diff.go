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
	"github.com/pmezard/go-difflib/difflib"

	"github.com/davidsansome/wk/encoding"
	"github.com/davidsansome/wk/utils"
)

func main() {
	flag.Parse()

	if len(flag.Args()) != 2 {
		flag.Usage()
		return
	}

	aName := flag.Args()[0]
	bName := flag.Args()[1]

	a, err := encoding.Open(aName)
	utils.Must(err)
	b, err := encoding.Open(bName)
	utils.Must(err)

	utils.Must(Diff(a, b, aName, bName))
}

func Diff(a, b encoding.Reader, aName, bName string) error {
	aCount, err := a.SubjectCount()
	if err != nil {
		return err
	}

	bCount, err := b.SubjectCount()
	if err != nil {
		return err
	}

	for i := 0; i < aCount && i < bCount; i++ {
		var astr, bstr string
		if spb, err := a.ReadSubject(i); err == nil {
			astr = proto.MarshalTextString(spb)
		}
		if spb, err := b.ReadSubject(i); err == nil {
			bstr = proto.MarshalTextString(spb)
		}

		aFile := fmt.Sprintf("%d %s", i, aName)
		bFile := fmt.Sprintf("%d %s", i, bName)

		ud := difflib.UnifiedDiff{
			A:        difflib.SplitLines(astr),
			B:        difflib.SplitLines(bstr),
			FromFile: aFile,
			ToFile:   bFile,
			Context:  3,
			Eol:      "\n",
		}

		diffString, _ := difflib.GetUnifiedDiffString(ud)
		if len(diffString) == 0 {
			continue
		}
		fmt.Println(diffString)
	}
	return nil
}
