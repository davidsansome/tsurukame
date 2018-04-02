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

package jsonapi

type Vocabulary struct {
	Stroke             int        `json:"stroke"`
	MeaningExplanation string     `json:"meaning_explanation"`
	ReadingExplanation string     `json:"reading_explanation"`
	Sentences          [][]string `json:"sentences"`
	Audio              string     `json:"audio"`
}
