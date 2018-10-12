all: proto.so

wanikani.pb.h: ../proto/wanikani.proto
	protoc ../proto/wanikani.proto --cpp_out=. --proto_path=../proto

wanikani.pb.cc: wanikani.pb.h

proto.so: proto.cc wanikani.pb.h wanikani.pb.cc
	g++ -Wall -fPIC -std=c++17 \
			-I../proto/ \
			-o proto.so -shared \
			proto.cc \
			../proto/wanikani.pb.cc \
			-lsqlite3 \
			-lprotobuf
