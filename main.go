package main

import (
	"flag"
	"fmt"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/wk/api"
	"github.com/davidsansome/wk/jsonapi"
	pb "github.com/davidsansome/wk/proto"
)

var (
	cookie   = flag.String("cookie", "", "Wanikani HTTP cookie")
	apiToken = flag.String("api-token", "", "Wanikani API v2 token")
)

func SubjectToProto(o *api.SubjectObject) *pb.Subject {
	var ret pb.Subject

	ret.Id = proto.Int32(int32(o.ID))
	ret.Level = proto.Int32(int32(o.Data.Level))
	ret.Slug = proto.String(o.Data.Slug)
	ret.DocumentUrl = proto.String(o.Data.DocumentURL)

	switch o.Object {
	case "radical":
		ret.Radical = &pb.Radical{
			Japanese: proto.String(o.Data.Character),
		}
		if len(o.Data.CharacterImages) >= 1 {
			ret.Radical.CharacterImage = proto.String(o.Data.CharacterImages[0].URL)
		}
		for _, meaning := range o.Data.Meanings {
			ret.Radical.Meanings = append(ret.Radical.Meanings, &pb.Meaning{
				Meaning:   proto.String(meaning.Meaning),
				IsPrimary: proto.Bool(meaning.Primary),
			})
		}
	}

	return &ret
}

func AddRadical(s *pb.Subject, r *jsonapi.Radical) {
	s.Radical.Mnemonic = proto.String(r.Mnemonic)
	s.Radical.MeaningNote = proto.String(r.MeaningNote)
}

func main() {
	flag.Parse()

	apiClient, err := api.New(*apiToken)
	if err != nil {
		panic(err)
	}

	jsonClient, err := jsonapi.New(*cookie)
	if err != nil {
		panic(err)
	}

	cur := apiClient.Subjects()
	for {
		subject, err := cur.Next()
		if err != nil {
			panic(err)
		}
		if subject == nil {
			break
		}

		r, err := jsonClient.GetRadical(subject.ID)
		if err != nil {
			panic(err)
		}

		spb := SubjectToProto(subject)
		AddRadical(spb, r)

		fmt.Printf("%s\n", proto.MarshalTextString(spb))
	}
}
