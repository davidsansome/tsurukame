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
	"time"

	"github.com/davidsansome/tsurukame/api"
	"github.com/davidsansome/tsurukame/converter"
	"github.com/davidsansome/tsurukame/encoding"
	"github.com/davidsansome/tsurukame/utils"
)

var (
	out             = flag.String("out", "data", "Output directory")
	apiToken        = flag.String("api-token", "", "Wanikani API v2 token")
	requestInterval = flag.Duration("request-interval", time.Millisecond*1200, "Time to wait between requests to the Wanikani API")
)

func main() {
	flag.Parse()

	// Create API clients.
	apiClient, err := api.New(*apiToken, *requestInterval)
	utils.Must(err)
	defer apiClient.Close()

	// Open directory.
	directory, err := encoding.OpenDirectory(*out)
	utils.Must(err)

	s := Scraper{apiClient, directory}
	if err := s.GetAll(); err != nil {
		panic(err)
	}
}

type Scraper struct {
	apiClient *api.Client
	directory encoding.ReadWriter
}

func (s *Scraper) GetAll() error {
	cur := s.apiClient.Subjects("")
SubjectLoop:
	for {
		subject, err := cur.Next()
		if err != nil {
			return err
		}
		if subject == nil {
			break SubjectLoop
		}

		if subject.Data.HiddenAt != "" {
			continue
		}

		spb, err := converter.SubjectToProto(subject)
		if err != nil {
			return err
		}

		// Write it to a file.
		if err := s.directory.WriteSubject(subject.ID, spb); err != nil {
			return err
		}
	}
	return nil
}
