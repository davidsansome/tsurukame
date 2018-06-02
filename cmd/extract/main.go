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

	"github.com/davidsansome/wk/encoding"
	"github.com/davidsansome/wk/utils"

	pb "github.com/davidsansome/wk/proto"
)

var (
	inputFile = flag.String("in", "data.bin", "Input file")
	outputDir = flag.String("out", "data", "Output directory")

	order = binary.LittleEndian
)

func main() {
	flag.Parse()
	utils.Must(Extract())
}

func Extract() error {
	reader, err := encoding.OpenFileReader(*inputFile)
	utils.Must(err)

	writer, err := encoding.OpenDirectory(*outputDir)
	utils.Must(err)
	defer writer.Close()

	return encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		return writer.WriteSubject(id, spb)
	})
}
