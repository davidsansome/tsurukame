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

		fmt.Printf("%d. %s\n", spb.GetId(), spb.GetSlug())
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
