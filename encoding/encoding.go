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
	"os"

	pb "github.com/davidsansome/wk/proto"
)

type SubjectIterator func(id int, subject *pb.Subject) error

type reader interface {
	SubjectCount() (int, error)
	HasSubject(id int) bool
	ReadSubject(id int) (*pb.Subject, error)
	ReadSubjectBytes(id int) ([]byte, error)
}

type writer interface {
	WriteSubject(id int, data *pb.Subject) error
}

type closer interface {
	Close() error
}

type ReadWriter interface {
	reader
	writer
	closer
}

type Reader interface {
	reader
	closer
}

type Writer interface {
	writer
	closer
}

func Open(path string) (Reader, error) {
	stat, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if stat.IsDir() {
		return OpenDirectory(path)
	}
	return OpenFileReader(path)
}

func ForEachSubject(reader Reader, it SubjectIterator) error {
	count, err := reader.SubjectCount()
	if err != nil {
		return err
	}

	for i := 0; i < count; i++ {
		if data, err := reader.ReadSubject(i); err == nil {
			if err := it(i, data); err != nil {
				return err
			}
		}
	}
	return nil
}
