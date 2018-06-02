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
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"strconv"

	"github.com/davidsansome/wk/encoding"
	"github.com/davidsansome/wk/utils"

	pb "github.com/davidsansome/wk/proto"
)

var (
	inputPath = flag.String("in", "data", "Input file/directory")
	out       = flag.String("out", "character_images", "Output file")
	pointSize = flag.Int("point-size", 60, "Size (in pt) of font images to create")
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

func main() {
	flag.Parse()
	utils.Must(Scrape())
}

func Scrape() error {
	reader, err := encoding.Open(*inputPath)
	utils.Must(err)

	// Create output directory.
	utils.Must(os.MkdirAll(*out, 0755))

	return encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		if spb.Radical == nil || spb.Radical.CharacterImage == nil || spb.GetJapanese() != "" {
			return nil
		}

		// Fetch the radical image.
		url := spb.Radical.GetCharacterImage()
		fmt.Println("Fetching", url)
		resp, err := http.Get(url)
		utils.Must(err)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return fmt.Errorf("HTTP %d from %s", resp.StatusCode, resp.Request.URL)
		}

		imgData, err := ioutil.ReadAll(resp.Body)
		utils.Must(err)

		dir := fmt.Sprintf("%s/radical-%d.imageset", *out, spb.GetId())
		utils.Must(os.MkdirAll(dir, 0755))

		// Write each size.
		for _, x := range []int{1, 2, 3} {
			px := *pointSize * x

			path := fmt.Sprintf("%s/radical-%d-%dx.png", dir, spb.GetId(), x)
			utils.Must(ScaleSVGData(imgData, path, px))
			fmt.Println("Saved", path)
		}

		// Write the Contents.json.
		path := fmt.Sprintf("%s/Contents.json", dir)
		utils.Must(ioutil.WriteFile(path, []byte(fmt.Sprintf(contentsJsonTemplate, spb.GetId(), spb.GetId(), spb.GetId())), 0644))
		return nil
	})
}

func ScaleSVG(svg, png string, size int) error {
	sizeString := strconv.Itoa(size)
	cmd := exec.Command("inkscape", "-z", "-e", png, "-w", sizeString, "-h", sizeString, svg)
	return cmd.Run()
}

func ScaleSVGData(svg []byte, png string, size int) error {
	tmpfile, err := ioutil.TempFile("", "tsurukame-svg")
	if err != nil {
		return err
	}

	defer os.Remove(tmpfile.Name())

	if _, err := tmpfile.Write(svg); err != nil {
		return err
	}
	if err := tmpfile.Close(); err != nil {
		return err
	}

	return ScaleSVG(tmpfile.Name(), png, size)
}
