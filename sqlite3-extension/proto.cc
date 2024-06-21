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

#include <cassert>
#include <cstring>
#include <google/protobuf/descriptor_database.h>
#include <google/protobuf/dynamic_message.h>
#include <google/protobuf/text_format.h>

#include "sqlite3ext.h"

#include "wanikani.pb.h"

using google::protobuf::Descriptor;
using google::protobuf::DescriptorPool;
using google::protobuf::DynamicMessageFactory;
using google::protobuf::Message;
using std::string;
using std::unique_ptr;


SQLITE_EXTENSION_INIT1
extern "C" {
int sqlite3_proto_init(sqlite3 *db, char **pzErrMsg, const sqlite3_api_routines *pApi);
}  // extern "C"


static void ProtoFunc(sqlite3_context *context, int argc, sqlite3_value **argv) {
  // Get the message name.
  string message_name(reinterpret_cast<const char*>(sqlite3_value_text(argv[0])),
                      static_cast<size_t>(sqlite3_value_bytes(argv[0])));
  message_name = "proto." + message_name;

  // Find the message in the descriptor pool.
  const Descriptor *descriptor =
      DescriptorPool::generated_pool()->FindMessageTypeByName(message_name);
  if (!descriptor) {
    sqlite3_result_error(context, "Couldn't find message descriptor", -1);
    return;
  }

  DynamicMessageFactory factory;
  unique_ptr<Message> message(factory.GetPrototype(descriptor)->New());

  // Get the serialized proto bytes.
  string message_data(reinterpret_cast<const char*>(sqlite3_value_text(argv[1])),
                      static_cast<size_t>(sqlite3_value_bytes(argv[1])));

  if (!message->ParseFromString(message_data)) {
    sqlite3_result_error(context, "Failed to parse proto", -1);
    return;
  }

  string text_format;
  if (!google::protobuf::TextFormat::PrintToString(*message, &text_format)) {
    sqlite3_result_error(context, "Failed to output text format", -1);
    return;
  }

  sqlite3_result_text(context, text_format.data(), text_format.size(), SQLITE_TRANSIENT);
}

int sqlite3_proto_init(sqlite3 *db,
                       char **pzErrMsg,
                       const sqlite3_api_routines *pApi) {
  SQLITE_EXTENSION_INIT2(pApi);
  return sqlite3_create_function(db, "proto", 2, SQLITE_UTF8, 0, ProtoFunc, 0, 0);
}
