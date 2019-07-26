.PHONY : generate

generate: wanikani.pb.go
	protoc --objc_out ../ios/proto wanikani.proto

wanikani.pb.go: ../proto/wanikani.proto
	go generate .
