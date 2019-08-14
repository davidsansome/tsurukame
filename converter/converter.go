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
	"strings"
	"strconv"

	"github.com/golang/protobuf/proto"

	"github.com/davidsansome/tsurukame/api"
	"github.com/davidsansome/tsurukame/jsonapi"
	pb "github.com/davidsansome/tsurukame/proto"
)

func SubjectToProto(o *api.SubjectObject) (*pb.Subject, error) {
	ret := pb.Subject{
		Id:          proto.Int32(int32(o.ID)),
		Level:       proto.Int32(int32(o.Data.Level)),
		Slug:        proto.String(o.Data.Slug),
		DocumentUrl: proto.String(o.Data.DocumentURL),
		Meanings:    convertMeanings(o.Data.Meanings, o.Data.AuxiliaryMeanings),
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
		ret.Kanji = &pb.Kanji{
			MeaningMnemonic: proto.String(o.Data.MeaningMnemonic),
			MeaningHint:     proto.String(o.Data.MeaningHint),
			ReadingMnemonic: proto.String(o.Data.ReadingMnemonic),
			ReadingHint:     proto.String(o.Data.ReadingHint),
		}

	case "vocabulary":
		ret.Vocabulary = &pb.Vocabulary{
			MeaningExplanation: proto.String(o.Data.MeaningMnemonic),
			ReadingExplanation: proto.String(o.Data.ReadingMnemonic),
		}
		if audio_ids := audioIds(o.Data.PronunciationAudios); audio_ids != nil {
			ret.Vocabulary.AudioIds = audio_ids
		}
		for _, p := range o.Data.PartsOfSpeech {
			pos, ok := convertPartOfSpeech(p)
			if !ok {
				return nil, fmt.Errorf("Unknown part of speech: %s\n", p)
			}
			ret.Vocabulary.PartsOfSpeech = append(ret.Vocabulary.PartsOfSpeech, pos)
		}
		for _, s := range o.Data.ContextSentences {
			ret.Vocabulary.Sentences = append(ret.Vocabulary.Sentences, &pb.Vocabulary_Sentence{
				Japanese: proto.String(s.Ja),
				English:  proto.String(s.En),
			})
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

func audioIds(audio []api.Audio) []int32 {
	audios := make([]int32, 0)
	for _, a := range audio {
		if a.ContentType == "audio/mpeg" {
			dash := strings.Index(a.Url, "-")
			id, _ := strconv.Atoi(a.Url[32:dash])
			audios = append(audios, int32(id))
		}
	}
	return audios
}

func convertMeanings(m []api.MeaningObject, a []api.AuxiliaryMeaningObject) []*pb.Meaning {
	var ret []*pb.Meaning
	for _, meaning := range m {
		p := &pb.Meaning{
			Meaning: proto.String(meaning.Meaning),
		}
		if meaning.Primary {
			p.Type = pb.Meaning_PRIMARY.Enum()
		} else {
			p.Type = pb.Meaning_SECONDARY.Enum()
		}
		ret = append(ret, p)
	}
	for _, auxiliary := range a {
		p := &pb.Meaning{
			Meaning: proto.String(auxiliary.Meaning),
		}
		switch auxiliary.Type {
		case "whitelist":
			p.Type = pb.Meaning_AUXILIARY_WHITELIST.Enum()
		case "blacklist":
			p.Type = pb.Meaning_BLACKLIST.Enum()
		default:
			panic(fmt.Sprintf("Unknown auxiliary type %s", auxiliary.Type))
		}
		ret = append(ret, p)
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
	p = strings.Replace(p, " ", "_", -1)
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
	case "no_adjective", "の_adjective":
		return pb.Vocabulary_NO_ADJECTIVE, true
	case "godan_verb":
		return pb.Vocabulary_GODAN_VERB, true
	case "na_adjective", "な_adjective":
		return pb.Vocabulary_NA_ADJECTIVE, true
	case "i_adjective", "い_adjective":
		return pb.Vocabulary_I_ADJECTIVE, true
	case "suffix":
		return pb.Vocabulary_SUFFIX, true
	case "adverb":
		return pb.Vocabulary_ADVERB, true
	case "suru_verb", "する_verb":
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
	if r.DeprecatedMnemonic != "" {
		s.Radical.DeprecatedMnemonic = proto.String(r.DeprecatedMnemonic)
	}
}
