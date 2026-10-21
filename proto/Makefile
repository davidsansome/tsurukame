.PHONY : generate swift

WANIKANI_API_PACKAGE = ../ios/WaniKaniAPI
SWIFT_BUILD = swift build -c release --package-path $(WANIKANI_API_PACKAGE)

generate: swift wanikani_api.pb.go

# Build protoc-gen-swift from the same swift-protobuf version that WaniKaniAPI depends on, so the
# generated code always matches the runtime library it's compiled against.
swift:
	$(SWIFT_BUILD) --product protoc-gen-swift
	protoc \
		--experimental_allow_proto3_optional \
		--plugin=protoc-gen-swift=$$($(SWIFT_BUILD) --show-bin-path)/protoc-gen-swift \
		--swift_out=../ios/WaniKaniAPI/Sources/WaniKaniAPI \
		--swift_opt=Visibility=Public \
		wanikani_api.proto

wanikani_api.pb.go: ../proto/wanikani_api.proto
	go generate .
