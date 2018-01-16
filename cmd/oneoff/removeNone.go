package main

import (
	"fmt"

	pb "github.com/davidsansome/wk/proto"
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
