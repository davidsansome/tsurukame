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
	"path"
	"sort"
	"strconv"

	"github.com/golang/protobuf/proto"

	pb "github.com/davidsansome/wk/proto"
)

var (
	directory = flag.String("directory", "data", "Directory to read data files from")
	all       = flag.Bool("all", false, "Dump everything instead of listing IDs")
)

func main() {
	flag.Parse()

	var err error
	if len(flag.Args()) == 1 {
		id, err := strconv.Atoi(flag.Args()[0])
		if err != nil {
			panic(err)
		}
		err = DumpOne(id)
	} else {
		err = ListAll()
	}

	if err != nil {
		panic(err)
	}
}

func ListAll() error {
	files, err := ioutil.ReadDir(*directory)
	if err != nil {
		return err
	}

	sort.Slice(files, func(i, j int) bool {
		in, _ := strconv.Atoi(files[i].Name())
		jn, _ := strconv.Atoi(files[j].Name())
		return in < jn
	})

	for _, f := range files {
		data, err := ioutil.ReadFile(path.Join(*directory, f.Name()))
		if err != nil {
			return err
		}

		var spb pb.Subject
		if err := proto.Unmarshal(data, &spb); err != nil {
			return err
		}

		if *all {
			fmt.Println(proto.MarshalTextString(&spb))
		} else {
			fmt.Printf("%d. %s\n", spb.GetId(), spb.GetSlug())
		}
	}
	return nil
}

func DumpOne(id int) error {
	data, err := ioutil.ReadFile(path.Join(*directory, strconv.Itoa(id)))
	if err != nil {
		return err
	}

	var spb pb.Subject
	if err := proto.Unmarshal(data, &spb); err != nil {
		return err
	}

	fmt.Println(proto.MarshalTextString(&spb))
	return nil
}
