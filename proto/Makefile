.PHONY : generate

generate: wanikani_api.pb.go
	protoc \
		--experimental_allow_proto3_optional \
		--swift_out=../ios/WaniKaniAPI/Sources/WaniKaniAPI \
		--swift_opt=Visibility=Public \
		wanikani_api.proto

wanikani_api.pb.go: ../proto/wanikani_api.proto
	go generate .
