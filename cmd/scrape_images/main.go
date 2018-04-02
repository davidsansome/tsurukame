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
	"image/png"
	"io/ioutil"
	"net/http"
	"os"
	"path"

	"github.com/golang/protobuf/proto"
	"github.com/nfnt/resize"

	pb "github.com/davidsansome/wk/proto"
)

var (
	directory = flag.String("directory", "data", "Directory to read data files from")
	out       = flag.String("out", "character_images", "Output file")
	pointSize = flag.Uint("point-size", 60, "Size (in pt) of font images to create")
)

const contentsJsonTemplate = `{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "radical-%d-1x.png",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "filename" : "radical-%d-2x.png",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "filename" : "radical-%d-3x.png",
      "scale" : "3x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
`

func Must(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	flag.Parse()
	Must(Scrape())
}

func Scrape() error {
	// List files.
	files, err := ioutil.ReadDir(*directory)
	Must(err)

	// Create output directory.
	Must(os.MkdirAll(*out, 0755))

	for _, f := range files {
		// Read the proto.
		pbData, err := ioutil.ReadFile(path.Join(*directory, f.Name()))
		Must(err)

		var spb pb.Subject
		Must(proto.Unmarshal(pbData, &spb))

		if spb.Radical == nil || spb.Radical.CharacterImage == nil {
			continue
		}

		// Fetch the radical image.
		resp, err := http.Get(spb.Radical.GetCharacterImage())
		Must(err)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return fmt.Errorf("HTTP %d from %s", resp.StatusCode, resp.Request.URL)
		}

		img, err := png.Decode(resp.Body)
		Must(err)

		dir := fmt.Sprintf("%s/radical-%d.imageset", *out, spb.GetId())
		Must(os.MkdirAll(dir, 0755))

		// Write each size.
		for _, x := range []uint{1, 2, 3} {
			px := *pointSize * x

			resizedImg := resize.Resize(px, px, img, resize.Lanczos3)

			// Write the new image.
			path := fmt.Sprintf("%s/radical-%d-%dx.png", dir, spb.GetId(), x)
			fh, err := os.Create(path)
			Must(err)
			defer fh.Close()
			Must(png.Encode(fh, resizedImg))
		}

		// Write the Contents.json.
		path := fmt.Sprintf("%s/Contents.json", dir)
		Must(ioutil.WriteFile(path, []byte(fmt.Sprintf(contentsJsonTemplate, spb.GetId(), spb.GetId(), spb.GetId())), 0644))
	}
	return nil
}
