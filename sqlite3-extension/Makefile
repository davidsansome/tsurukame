all: proto.so

wanikani.pb.h: ../proto/wanikani.proto
	protoc ../proto/wanikani.proto --cpp_out=. --proto_path=../proto

wanikani.pb.cc: wanikani.pb.h

proto.so: proto.cc wanikani.pb.h wanikani.pb.cc
	g++ -Wall -fPIC -std=c++17 \
			-L/usr/local/lib/ \
			-o proto.so -shared \
			proto.cc \
			wanikani.pb.cc \
			-lsqlite3 \
			-lprotobuf

clean:
	rm -f proto.so wanikani.pb.h wanikani.pb.cc
