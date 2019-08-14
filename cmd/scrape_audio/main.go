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

	"github.com/davidsansome/tsurukame/encoding"
	"github.com/davidsansome/tsurukame/utils"

	pb "github.com/davidsansome/tsurukame/proto"
)

var (
	inputPath = flag.String("in", "data", "Input file/directory")
	out       = flag.String("out", "www/audio", "Output directory")
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

	filenamesByLevel := map[int][]string{}

	if err := encoding.ForEachSubject(reader, func(id int, spb *pb.Subject) error {
		if spb.Vocabulary == nil || spb.Vocabulary.AudioIds == nil {
			return nil
		}
		audio_ids := spb.Vocabulary.GetAudioIds()

		for _, audio_id := range audio_ids {
			outFilename := fmt.Sprintf("a%d.mp3", audio_id)
			outPath := path.Join(*out, outFilename)

			level := int(spb.GetLevel())
			filenamesByLevel[level] = append(filenamesByLevel[level], outFilename)
			if _, err := os.Stat(outPath); !os.IsNotExist(err) {
				fmt.Printf("Skipping %s (already exists)\n", outPath)
				continue
			}

			// Fetch the audio file.
			url := fmt.Sprintf("https://cdn.wanikani.com/audios/%d-subject-%d.mp3", audio_id, id)
			fmt.Printf("Fetching %s to %s\n", url, outPath)
			resp, err := http.Get(url)
			utils.Must(err)
			if resp.StatusCode != http.StatusOK {
				return fmt.Errorf("HTTP %d from %s", resp.StatusCode, resp.Request.URL)
			}
			defer resp.Body.Close()

			// Open the output file.
			fh, err := os.Create(outPath)
			if err != nil {
				return err
			}
			defer fh.Close()

			// Write the output file.
			if _, err := io.Copy(fh, resp.Body); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		return err
	}

	// Create archives for level groups.
	var definitions []string
	for i := 0; i < 6; i++ {
		startLevel := i*10 + 1
		endLevel := (i + 1) * 10
		var subjectIDs []string
		for level := startLevel; level <= endLevel; level++ {
			subjectIDs = append(subjectIDs, filenamesByLevel[level]...)
		}
		filename := fmt.Sprintf("a-levels-%d-%d", startLevel, endLevel)
		sizeBytes, err := createArchive(filename, subjectIDs)
		if err != nil {
			return err
		}
		definitions = append(definitions,
			fmt.Sprintf(`{@"%s.tar.lzfse", @"Levels %d-%d", %d},`, filename, startLevel, endLevel, sizeBytes))
	}

	fmt.Println("\nstatic const AvailablePackage kAvailablePackages[] = {")
	for _, definition := range definitions {
		fmt.Printf("  %s\n", definition)
	}
	fmt.Println("};")

	return nil
}

func createArchive(filename string, subjectIDs []string) (int64, error) {
	tarFilename := path.Join(*out, fmt.Sprintf("%s.tar", filename))
	lzfseFilename := path.Join(*out, fmt.Sprintf("%s.tar.lzfse", filename))
	fmt.Println("Creating archive", lzfseFilename)

	tarArgs := []string{"-cf", tarFilename, "-C", *out}
	tarArgs = append(tarArgs, subjectIDs...)
	if err := exec.Command("tar", tarArgs...).Run(); err != nil {
		return 0, err
	}
	defer os.Remove(tarFilename)

	if err := exec.Command("lzfse", "-encode", "-i", tarFilename, "-o", lzfseFilename).Run(); err != nil {
		return 0, err
	}

	st, err := os.Stat(lzfseFilename)
	if err != nil {
		return 0, err
	}
	return st.Size(), err
}
