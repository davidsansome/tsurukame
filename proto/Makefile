all: wanikani.pb.h wanikani.pb.go

wanikani.pb.h: wanikani.proto
	protoc wanikani.proto --cpp_out=.

wanikani.pb.go: wanikani.proto
	go generate .
