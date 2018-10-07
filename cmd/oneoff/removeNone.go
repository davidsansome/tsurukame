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
	"fmt"

	pb "github.com/davidsansome/tsurukame/proto"
)

func RemoveNone(subject pb.Subject) pb.Subject {
	var readings []*pb.Reading
	for _, reading := range subject.Readings {
		if reading.GetReading() != "None" {
			readings = append(readings, reading)
		} else {
			fmt.Printf("Removing None reading from %d. %s %s\n",
				subject.GetId(), subject.GetJapanese(), subject.GetMeanings()[0].GetMeaning())
		}
	}
	subject.Readings = readings
	return subject
}
