proto.so: proto.cc ../proto/wanikani.pb.h ../proto/wanikani.pb.cc
	g++ -Wall -fPIC -std=c++17 \
			-I../proto/ \
			-o proto.so -shared \
			-lsqlite3 \
			-lprotobuf \
			proto.cc \
			../proto/wanikani.pb.cc