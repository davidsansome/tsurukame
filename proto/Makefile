.PHONY : generate

generate: wanikani.pb.go
	protoc --experimental_allow_proto3_optional --objc_out=../ios/proto wanikani.proto

wanikani.pb.go: ../proto/wanikani.proto
	go generate .
