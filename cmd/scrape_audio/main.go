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
	"io"
	"net/http"
	"os"
	"os/exec"
	"path"
	"strconv"
	"strings"

	"github.com/davidsansome/tsurukame/encoding"
	"github.com/davidsansome/tsurukame/utils"

	pb "github.com/davidsansome/tsurukame/proto"
)

var (
	inputPath = flag.String("in", "data", "Input file/directory")
	out       = flag.String("out", "www/audio", "Output directory")
)

const (
	urlPrefix = "https://cdn.wanikani.com/subjects/audio/"
)

func main() {
	flag.Parse()
	utils.Must(Scrape())
}

func Scrape() error {
	reader, err := encoding.Open(*inputPath)
	utils.Must(err)

	// Create output directory.
	utils.Must(os.MkdirAll(*out, 0755))

	subjectIDByLevel := map[int][]string{}

	if err := encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		if spb.Vocabulary == nil || spb.Vocabulary.Audio == nil {
			return nil
		}
		url := urlPrefix + spb.Vocabulary.GetAudio()
		idString := strconv.Itoa(id)
		outPath := path.Join(*out, idString)

		level := int(spb.GetLevel())
		subjectIDByLevel[level] = append(subjectIDByLevel[level], idString)
		if _, err := os.Stat(outPath); !os.IsNotExist(err) {
			fmt.Printf("Skipping %s (already exists)\n", outPath)
			return nil
		}

		// Fetch the audio file.
		fmt.Printf("Fetching %s to %s\n", url, outPath)
		resp, err := http.Get(url)
		utils.Must(err)
		if resp.StatusCode != http.StatusOK {
			url = strings.Replace(url, "ogg", "mp3", 1)
			fmt.Printf("HTTP %d from %s, trying mp3 instead\n", resp.StatusCode, resp.Request.URL)
			resp, err = http.Get(url)
			utils.Must(err)
			if resp.StatusCode != http.StatusOK {
				return fmt.Errorf("HTTP %d from %s", resp.StatusCode, resp.Request.URL)
			}
		}
		defer resp.Body.Close()

		fh, err := os.Create(outPath)
		if err != nil {
			return err
		}
		defer fh.Close()

		if _, err := io.Copy(fh, resp.Body); err != nil {
			return err
		}
		return nil
	}); err != nil {
		return err
	}

	for i := 0; i < 6; i++ {
		startLevel := i*10 + 1
		endLevel := (i + 1) * 10
		var subjectIDs []string
		for level := startLevel; level <= endLevel; level++ {
			subjectIDs = append(subjectIDs, subjectIDByLevel[level]...)
		}
		if err := createArchive(fmt.Sprintf("levels-%d-%d", startLevel, endLevel), subjectIDs); err != nil {
			return err
		}
	}

	return nil
}

func createArchive(filename string, subjectIDs []string) error {
	tarFilename := path.Join(*out, fmt.Sprintf("%s.tar", filename))
	lzfseFilename := path.Join(*out, fmt.Sprintf("%s.tar.lzfse", filename))
	fmt.Println("Creating archive", lzfseFilename)

	tarArgs := []string{"-cf", tarFilename, "-C", *out}
	tarArgs = append(tarArgs, subjectIDs...)
	if err := exec.Command("tar", tarArgs...).Run(); err != nil {
		return err
	}
	defer os.Remove(tarFilename)

	return exec.Command("lzfse", "-encode", "-i", tarFilename, "-o", lzfseFilename).Run()
}
