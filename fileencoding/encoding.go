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
