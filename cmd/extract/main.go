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
	"io/ioutil"

	"github.com/davidsansome/wk/indexedencoding"
)

var (
	directory     = flag.String("directory", "data", "Output directory")
	inputFilename = flag.String("input_filename", "data.bin", "Input file")

	order = binary.LittleEndian
)

func main() {
	flag.Parse()

	if err := Extract(); err != nil {
		panic(err)
	}
}

func Extract() error {
	r, err := indexedencoding.NewReader(*inputFilename)
	if err != nil {
		return err
	}

	for i := uint32(1); i < r.Count(); i++ {
		data, err := r.ReadSubjectBytes(i)
		if err != nil {
			return err
		}

		outputFilename := fmt.Sprintf("%s/%d", *directory, i)
		fmt.Println("Writing", outputFilename)
		if err := ioutil.WriteFile(outputFilename, data, 0644); err != nil {
			return err
		}
	}
	return nil
}
