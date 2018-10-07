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
	"strconv"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/tsurukame/encoding"
	"github.com/davidsansome/tsurukame/utils"

	pb "github.com/davidsansome/tsurukame/proto"
)

var (
	all = flag.Bool("all", false, "Dump everything instead of listing IDs")
)

func main() {
	flag.Parse()

	if len(flag.Args()) == 0 {
		flag.Usage()
		return
	}

	path := flag.Args()[0]
	reader, err := encoding.Open(path)
	utils.Must(err)

	if len(flag.Args()) == 2 {
		id, err := strconv.Atoi(flag.Args()[1])
		utils.Must(err)
		err = DumpOne(reader, id)
	} else {
		err = ListAll(reader)
	}

	utils.Must(err)
}

func ListAll(reader encoding.Reader) error {
	return encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		if *all {
			fmt.Println(proto.MarshalTextString(spb))
		} else {
			fmt.Printf("%d. %s\n", spb.GetId(), spb.GetSlug())
		}
		return nil
	})
}

func DumpOne(reader encoding.Reader, id int) error {
	data, err := reader.ReadSubject(id)
	if err != nil {
		return err
	}

	fmt.Println(proto.MarshalTextString(data))
	return nil
}
