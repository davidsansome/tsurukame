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
	"log"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/wk/api"
	"github.com/davidsansome/wk/converter"
	"github.com/davidsansome/wk/encoding"
	"github.com/davidsansome/wk/jsonapi"
	"github.com/davidsansome/wk/utils"
)

var (
	out      = flag.String("out", "data", "Output directory")
	cookie   = flag.String("cookie", "", "Wanikani HTTP cookie")
	apiToken = flag.String("api-token", "", "Wanikani API v2 token")
	apiOnly  = flag.Bool("api-only", false, "Use the API only, merge with existing data")
)

func main() {
	flag.Parse()

	// Create API clients.
	apiClient, err := api.New(*apiToken)
	utils.Must(err)

	jsonClient, err := jsonapi.New(*cookie)
	utils.Must(err)

	// Open directory.
	directory, err := encoding.OpenDirectory(*out)
	utils.Must(err)

	s := Scraper{apiClient, jsonClient, directory}
	if err := s.GetAll(); err != nil {
		panic(err)
	}
}

type Scraper struct {
	apiClient  *api.Client
	jsonClient *jsonapi.Client
	directory  encoding.ReadWriter
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

		if *apiOnly {
			existingSpb, err := s.directory.ReadSubject(subject.ID)
			if err != nil {
				return err
			}
			// Don't merge repeated fields.
			existingSpb.ComponentSubjectIds = nil
			existingSpb.Meanings = nil
			existingSpb.Readings = nil
			if existingSpb.Vocabulary != nil {
				existingSpb.Vocabulary.PartsOfSpeech = nil
			}
			proto.Merge(existingSpb, spb)
			spb = existingSpb
		} else {
			// Don't fetch this subject again if we've already got it.
			if s.directory.HasSubject(subject.ID) {
				continue SubjectLoop
			}

			// Fetch the other bits.
			switch {
			case spb.Radical != nil:
				r, err := s.jsonClient.GetRadical(subject.ID)
				if err != nil {
					log.Printf("Error getting radical %d: %v", subject.ID, err)
					continue SubjectLoop
				}
				converter.AddRadical(spb, r)

			case spb.Kanji != nil:
				r, err := s.jsonClient.GetKanji(subject.ID)
				if err != nil {
					log.Printf("Error getting kanji %d: %v", subject.ID, err)
					continue SubjectLoop
				}
				converter.AddKanji(spb, r)

			case spb.Vocabulary != nil:
				r, err := s.jsonClient.GetVocabulary(subject.ID)
				if err != nil {
					log.Printf("Error getting vocabulary %d: %v", subject.ID, err)
					continue SubjectLoop
				}
				converter.AddVocabulary(spb, r)
			}
		}

		// Write it to a file.
		if err := s.directory.WriteSubject(subject.ID, spb); err != nil {
			return err
		}
	}
	return nil
}
