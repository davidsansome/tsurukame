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

package fileencoding

import (
	"flag"
	"io/ioutil"
	"path"
	"strconv"

	"github.com/golang/protobuf/proto"

	pb "github.com/davidsansome/wk/proto"
)

var (
	DataDirectory = flag.String("directory", "data", "Directory to store data files")
)

func ReadSubjectByFilename(filename string) (*pb.Subject, error) {
	data, err := ioutil.ReadFile(path.Join(*DataDirectory, filename))
	if err != nil {
		return nil, err
	}

	var ret pb.Subject
	if err := proto.Unmarshal(data, &ret); err != nil {
		return nil, err
	}
	return &ret, nil
}

func ReadSubjectByID(id int32) (*pb.Subject, error) {
	return ReadSubjectByFilename(strconv.Itoa(int(id)))
}

func ListFilenames() ([]string, error) {
	files, err := ioutil.ReadDir(*DataDirectory)
	if err != nil {
		return nil, err
	}

	var ret []string
	for _, fileInfo := range files {
		ret = append(ret, fileInfo.Name())
	}
	return ret, nil
}
