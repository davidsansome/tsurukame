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

package encoding

import (
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"strconv"

	"github.com/golang/protobuf/proto"

	pb "github.com/davidsansome/tsurukame/proto"
)

type directoryEncoding struct {
	path string
}

func OpenDirectory(path string) (ReadWriter, error) {
	stat, err := os.Stat(path)
	if os.IsNotExist(err) {
		return nil, fmt.Errorf("directory %s does not exist", path)
	}
	if !stat.IsDir() {
		return nil, fmt.Errorf("%s is not a directory", path)
	}
	return &directoryEncoding{path}, nil
}

func (e *directoryEncoding) SubjectCount() (int, error) {
	files, err := ioutil.ReadDir(e.path)
	if err != nil {
		return 0, err
	}

	var count int
	for _, fileInfo := range files {
		if num, err := strconv.Atoi(fileInfo.Name()); err == nil {
			if num > count {
				count = num
			}
		}
	}
	return count + 1, nil
}

func (e *directoryEncoding) HasSubject(id int) bool {
	stat, err := os.Stat(e.filename(id))
	return err == nil && !stat.IsDir()
}

func (e *directoryEncoding) ReadSubject(id int) (*pb.Subject, error) {
	data, err := e.ReadSubjectBytes(id)
	if err != nil {
		return nil, err
	}

	var ret pb.Subject
	if err := proto.Unmarshal(data, &ret); err != nil {
		return nil, err
	}
	return &ret, nil
}

func (e *directoryEncoding) ReadSubjectBytes(id int) ([]byte, error) {
	return ioutil.ReadFile(e.filename(id))
}

func (e *directoryEncoding) Close() error {
	return nil
}

func (e *directoryEncoding) WriteSubject(id int, data *pb.Subject) error {
	b, err := proto.Marshal(data)
	if err != nil {
		return err
	}
	return e.WriteSubjectBytes(id, b)
}

func (e *directoryEncoding) WriteSubjectBytes(id int, data []byte) error {
	return ioutil.WriteFile(e.filename(id), data, 0644)
}

func (e *directoryEncoding) filename(id int) string {
	return path.Join(e.path, strconv.Itoa(id))
}
