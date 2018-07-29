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
	"encoding/binary"
	"fmt"
	"os"

	"github.com/golang/protobuf/proto"

	pb "github.com/davidsansome/wk/proto"
)

var (
	order = binary.LittleEndian
)

type fileEncodingReader struct {
	fh      *os.File
	count   uint32
	offsets []uint32
}

func OpenFileReader(filename string) (Reader, error) {
	fh, err := os.Open(filename)
	if err != nil {
		return nil, err
	}

	// Read the index.
	var count uint32
	if err := binary.Read(fh, order, &count); err != nil {
		fh.Close()
		return nil, err
	}

	subjectOffsets := make([]uint32, count)
	for i := uint32(0); i < count; i++ {
		if err := binary.Read(fh, order, &subjectOffsets[i]); err != nil {
			fh.Close()
			return nil, err
		}
	}

	return &fileEncodingReader{
		fh:      fh,
		count:   count,
		offsets: subjectOffsets,
	}, nil
}

func (e *fileEncodingReader) SubjectCount() (int, error) {
	return int(e.count), nil
}

func (e *fileEncodingReader) HasSubject(id int) bool {
	return id >= 0 && uint32(id) < e.count
}

func (e *fileEncodingReader) ReadSubject(id int) (*pb.Subject, error) {
	data, err := e.ReadSubjectBytes(id)
	if err != nil {
		return nil, err
	}

	var s pb.Subject
	if err := proto.Unmarshal(data, &s); err != nil {
		return nil, err
	}

	s.Id = proto.Int32(int32(id))
	return &s, nil
}

func (e *fileEncodingReader) ReadSubjectBytes(id int) ([]byte, error) {
	if id < 0 || uint32(id) >= e.count {
		return nil, fmt.Errorf("Subject ID %d out of range 0-%d", id, e.count)
	}

	var length uint32
	if uint32(id) == e.count-1 {
		stat, err := e.fh.Stat()
		if err != nil {
			return nil, err
		}
		length = uint32(stat.Size()) - e.offsets[id]
	} else {
		length = e.offsets[id+1] - e.offsets[id]
	}

	data := make([]byte, length)
	if _, err := e.fh.ReadAt(data, int64(e.offsets[id])); err != nil {
		return nil, err
	}
	return data, nil
}

func (e *fileEncodingReader) Close() error {
	return e.fh.Close()
}

type fileEncodingWriter struct {
	fh       *os.File
	subjects [][]byte
	header   pb.DataFileHeader
}

func OpenFileWriter(filename string) (Writer, error) {
	fh, err := os.Create(filename)
	if err != nil {
		return nil, err
	}

	return &fileEncodingWriter{
		fh:       fh,
		subjects: make([][]byte, 0),
	}, nil
}

func (e *fileEncodingWriter) WriteSubject(id int, subject *pb.Subject) error {
	subject.Id = nil

	// Marshal and store the proto.
	b, err := proto.Marshal(subject)
	if err != nil {
		return err
	}
	for len(e.subjects) <= int(id) {
		e.subjects = append(e.subjects, nil)
	}
	e.subjects[id] = b

	// Add to the per-level counts in the metadata.
	levelIndex := subject.GetLevel() - 1
	for len(e.header.SubjectsByLevel) <= int(levelIndex) {
		e.header.SubjectsByLevel = append(e.header.SubjectsByLevel, &pb.SubjectsByLevel{})
	}
	index := e.header.SubjectsByLevel[levelIndex]
	if subject.Radical != nil {
		index.Radicals = append(index.Radicals, int32(id))
	}
	if subject.Kanji != nil {
		index.Kanji = append(index.Kanji, int32(id))
	}
	if subject.Vocabulary != nil {
		index.Vocabulary = append(index.Vocabulary, int32(id))
	}

	return nil
}

func (e *fileEncodingWriter) Close() error {
	// Calculate the offsets of each message.
	var offset int32
	for _, d := range e.subjects {
		e.header.SubjectByteOffset = append(e.header.SubjectByteOffset, offset)
		offset += int32(len(d))
	}

	// Seralise the header.
	headerBytes, err := proto.Marshal(&e.header)
	if err != nil {
		return err
	}

	// Write the header and its length.
	if err := binary.Write(e.fh, order, uint32(len(headerBytes))); err != nil {
		return err
	}
	if _, err := e.fh.Write(headerBytes); err != nil {
		return err
	}

	// Write each encoded protobuf.
	for _, d := range e.subjects {
		if _, err := e.fh.Write(d); err != nil {
			return err
		}
	}

	return e.fh.Close()
}
