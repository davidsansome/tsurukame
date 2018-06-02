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

package converter

import (
	"fmt"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/wk/api"
	"github.com/davidsansome/wk/jsonapi"
	pb "github.com/davidsansome/wk/proto"
)

func SubjectToProto(o *api.SubjectObject) (*pb.Subject, error) {
	ret := pb.Subject{
		Id:          proto.Int32(int32(o.ID)),
		Level:       proto.Int32(int32(o.Data.Level)),
		Slug:        proto.String(o.Data.Slug),
		DocumentUrl: proto.String(o.Data.DocumentURL),
		Meanings:    convertMeanings(o.Data.Meanings),
	}

	if len(o.Data.Character) != 0 {
		ret.Japanese = proto.String(o.Data.Character)
	} else {
		ret.Japanese = proto.String(o.Data.Characters)
	}

	if o.Object == "kanji" || o.Object == "vocabulary" {
		ret.Readings = convertReadings(o.Data.Readings)
		ret.ComponentSubjectIds = convertSubjectIDArray(o.Data.ComponentSubjectIDs)
	}
	if o.Object == "radical" || o.Object == "kanji" {
		ret.AmalgamationSubjectIds = convertSubjectIDArray(o.Data.AmalgamationSubjectIDs)
	}

	switch o.Object {
	case "radical":
		ret.Radical = &pb.Radical{}
		if len(o.Data.CharacterImages) >= 1 {
			ret.Radical.CharacterImage =
				proto.String(bestCharacterImageURL(o.ID, o.Data.CharacterImages))
		}

	case "kanji":
		ret.Kanji = &pb.Kanji{}

	case "vocabulary":
		ret.Vocabulary = &pb.Vocabulary{}
		for _, p := range o.Data.PartsOfSpeech {
			pos, ok := convertPartOfSpeech(p)
			if !ok {
				return nil, fmt.Errorf("Unknown part of speech: %s\n", p)
			}
			ret.Vocabulary.PartsOfSpeech = append(ret.Vocabulary.PartsOfSpeech, pos)
		}
	}

	return &ret, nil
}

func bestCharacterImageURL(id int, images []api.CharacterImage) string {
	for _, i := range images {
		if i.ContentType == "image/svg+xml" && i.Metadata.InlineStyles {
			return i.URL
		}
	}
	panic(fmt.Sprintf("No SVG found for radical %d", id))
}

func convertMeanings(m []api.MeaningObject) []*pb.Meaning {
	var ret []*pb.Meaning
	for _, meaning := range m {
		ret = append(ret, &pb.Meaning{
			Meaning:   proto.String(meaning.Meaning),
			IsPrimary: proto.Bool(meaning.Primary),
		})
	}
	return ret
}

func convertReadings(r []api.ReadingObject) []*pb.Reading {
	var ret []*pb.Reading
	for _, reading := range r {
		if reading.Reading == "None" {
			continue
		}
		rpb := &pb.Reading{
			Reading:   proto.String(reading.Reading),
			IsPrimary: proto.Bool(reading.Primary),
		}
		switch reading.Type {
		case "onyomi":
			rpb.Type = pb.Reading_ONYOMI.Enum()
		case "kunyomi":
			rpb.Type = pb.Reading_KUNYOMI.Enum()
		case "nanori":
			rpb.Type = pb.Reading_NANORI.Enum()
		}
		ret = append(ret, rpb)
	}
	return ret
}

func convertSubjectIDArray(c []int) []int32 {
	var ret []int32
	for _, id := range c {
		ret = append(ret, int32(id))
	}
	return ret
}

func convertPartOfSpeech(p string) (pb.Vocabulary_PartOfSpeech, bool) {
	switch p {
	case "noun":
		return pb.Vocabulary_NOUN, true
	case "numeral":
		return pb.Vocabulary_NUMERAL, true
	case "intransitive_verb":
		return pb.Vocabulary_INTRANSITIVE_VERB, true
	case "ichidan_verb":
		return pb.Vocabulary_ICHIDAN_VERB, true
	case "transitive_verb":
		return pb.Vocabulary_TRANSITIVE_VERB, true
	case "no_adjective":
		return pb.Vocabulary_NO_ADJECTIVE, true
	case "godan_verb":
		return pb.Vocabulary_GODAN_VERB, true
	case "na_adjective":
		return pb.Vocabulary_NA_ADJECTIVE, true
	case "i_adjective":
		return pb.Vocabulary_I_ADJECTIVE, true
	case "suffix":
		return pb.Vocabulary_SUFFIX, true
	case "adverb":
		return pb.Vocabulary_ADVERB, true
	case "suru_verb":
		return pb.Vocabulary_SURU_VERB, true
	case "prefix":
		return pb.Vocabulary_PREFIX, true
	case "proper_noun":
		return pb.Vocabulary_PROPER_NOUN, true
	case "expression":
		return pb.Vocabulary_EXPRESSION, true
	case "adjective":
		return pb.Vocabulary_ADJECTIVE, true
	case "interjection":
		return pb.Vocabulary_INTERJECTION, true
	case "counter":
		return pb.Vocabulary_COUNTER, true
	case "pronoun":
		return pb.Vocabulary_PRONOUN, true
	case "conjunction":
		return pb.Vocabulary_CONJUNCTION, true
	}
	return pb.Vocabulary_NOUN, false
}

func AddRadical(s *pb.Subject, r *jsonapi.Radical) {
	s.Radical.Mnemonic = proto.String(r.Mnemonic)
}

func AddKanji(s *pb.Subject, k *jsonapi.Kanji) {
	s.Kanji.MeaningMnemonic = proto.String(k.MeaningMnemonic)
	s.Kanji.MeaningHint = proto.String(k.MeaningHint)
	s.Kanji.ReadingMnemonic = proto.String(k.ReadingMnemonic)
	s.Kanji.ReadingHint = proto.String(k.ReadingHint)
}

func AddVocabulary(s *pb.Subject, v *jsonapi.Vocabulary) {
	s.Vocabulary.MeaningExplanation = proto.String(v.MeaningExplanation)
	s.Vocabulary.ReadingExplanation = proto.String(v.ReadingExplanation)
	s.Vocabulary.Audio = proto.String(v.Audio)
	for _, jp_en := range v.Sentences {
		s.Vocabulary.Sentences = append(s.Vocabulary.Sentences, &pb.Vocabulary_Sentence{
			Japanese: proto.String(jp_en[0]),
			English:  proto.String(jp_en[1]),
		})
	}
}
