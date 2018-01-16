package main

import (
	"flag"
	"io/ioutil"
	"path"

	"github.com/golang/protobuf/proto"

	pb "github.com/davidsansome/wk/proto"
)

type Mapper func(pb.Subject) pb.Subject

var (
	directory = flag.String("directory", "data", "Directory to read data files from")
	mapper    = flag.String("mapper", "", "One-off mapper to run")

	mappers = map[string]Mapper{
		// Put mappers here.
		"RemoveNone": RemoveNone,
	}
)

func main() {
	flag.Parse()

	mapper := mappers[*mapper]
	if mapper == nil {
		panic("Mapper not found")
	}
	if err := ListAll(mapper); err != nil {
		panic(err)
	}
}

func ListAll(mapper Mapper) error {
	files, err := ioutil.ReadDir(*directory)
	if err != nil {
		return err
	}

	for _, f := range files {
		filename := path.Join(*directory, f.Name())
		data, err := ioutil.ReadFile(filename)
		if err != nil {
			return err
		}

		var oldSubject pb.Subject
		if err := proto.Unmarshal(data, &oldSubject); err != nil {
			return err
		}

		newSubject := mapper(oldSubject)

		data, err = proto.Marshal(&newSubject)
		if err != nil {
			return err
		}
		if err := ioutil.WriteFile(filename, data, 0644); err != nil {
			return err
		}
	}
	return nil
}
