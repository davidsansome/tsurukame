package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/wk/api"
	"github.com/davidsansome/wk/converter"
	"github.com/davidsansome/wk/jsonapi"
)

var (
	cookie    = flag.String("cookie", "", "Wanikani HTTP cookie")
	apiToken  = flag.String("api-token", "", "Wanikani API v2 token")
	directory = flag.String("directory", "data", "Output directory")
)

func main() {
	flag.Parse()

	// Create API clients.
	apiClient, err := api.New(*apiToken)
	if err != nil {
		panic(err)
	}

	jsonClient, err := jsonapi.New(*cookie)
	if err != nil {
		panic(err)
	}

	if _, err := os.Stat(*directory); os.IsNotExist(err) {
		panic(err)
	}

	s := Scraper{apiClient, jsonClient, *directory}
	if err := s.GetAll(); err != nil {
		panic(err)
	}
}

type Scraper struct {
	apiClient  *api.Client
	jsonClient *jsonapi.Client
	directory  string
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

		// Don't fetch this subject again if we've already got it.
		filename := fmt.Sprintf("%s/%d", s.directory, subject.ID)
		if _, err := os.Stat(filename); !os.IsNotExist(err) {
			continue SubjectLoop
		}

		spb := converter.SubjectToProto(subject)

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

		// Write it to a file.
		data, err := proto.Marshal(spb)
		if err != nil {
			return err
		}

		err = ioutil.WriteFile(filename, data, 0644)
		if err != nil {
			return err
		}
	}
	return nil
}
