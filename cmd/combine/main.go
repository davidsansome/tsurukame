package main

import (
	"encoding/binary"
	"flag"
	"io/ioutil"
	"os"
	"path"

	"github.com/golang/protobuf/proto"

	pb "github.com/davidsansome/wk/proto"
)

var (
	directory = flag.String("directory", "data", "Directory to read data files from")
	out       = flag.String("out", "data.bin", "Output file")

	order = binary.LittleEndian
)

func main() {
	flag.Parse()

	if err := Combine(); err != nil {
		panic(err)
	}

}

func Combine() error {
	// List files.
	files, err := ioutil.ReadDir(*directory)
	if err != nil {
		return err
	}

	// Read everything into memory.
	all := make([][]byte, len(files))
	for _, f := range files {
		data, err := ioutil.ReadFile(path.Join(*directory, f.Name()))
		if err != nil {
			return err
		}

		var spb pb.Subject
		if err := proto.Unmarshal(data, &spb); err != nil {
			return err
		}
		id := spb.GetId()

		// Remove fields we don't care about for the iOS app.
		spb.DocumentUrl = nil
		spb.Id = nil
		if spb.Radical != nil && spb.Radical.CharacterImage != nil {
			spb.Radical.CharacterImage = nil
			spb.Radical.HasCharacterImageFile = proto.Bool(true)
		}

		data, err = proto.Marshal(&spb)
		if err != nil {
			return err
		}

		// Make space in the array for this ID.
		for len(all) <= int(id) {
			all = append(all, nil)
		}
		all[id] = data
	}

	fh, err := os.Create(*out)
	if err != nil {
		return err
	}
	defer fh.Close()

	// Write the index.
	binary.Write(fh, order, uint32(len(all)))
	offset := 4 + 4*len(all)
	for _, d := range all {
		binary.Write(fh, order, uint32(offset))
		offset += len(d)
	}

	// Write each encoded protobuf.
	for _, d := range all {
		fh.Write(d)
	}

	return nil
}
