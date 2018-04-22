package indexedencoding

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

type Reader struct {
	fh      *os.File
	count   uint32
	offsets []uint32
}

func NewReader(filename string) (*Reader, error) {
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

	return &Reader{
		fh:      fh,
		count:   count,
		offsets: subjectOffsets,
	}, nil
}

func (r *Reader) Close() error {
	return r.fh.Close()
}

func (r *Reader) Count() uint32 {
	return r.count
}

func (r *Reader) ReadSubjectBytes(id uint32) ([]byte, error) {
	s, err := r.ReadSubject(id)
	if err != nil {
		return nil, err
	}

	return proto.Marshal(s)
}

func (r *Reader) ReadSubject(id uint32) (*pb.Subject, error) {
	if id < 0 || id >= r.count {
		panic(fmt.Sprintf("Subject ID %d out of range 0-%d", id, r.count))
	}

	var length uint32
	if id == r.count-1 {
		stat, err := r.fh.Stat()
		if err != nil {
			return nil, err
		}
		length = uint32(stat.Size()) - r.offsets[id]
	} else {
		length = r.offsets[id+1] - r.offsets[id]
	}

	data := make([]byte, length)
	if _, err := r.fh.ReadAt(data, int64(r.offsets[id])); err != nil {
		return nil, err
	}

	var s pb.Subject
	if err := proto.Unmarshal(data, &s); err != nil {
		return nil, err
	}

	s.Id = proto.Int32(int32(id))
	return &s, nil
}
