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

#import "DataLoader.h"

#include <arpa/inet.h>

// TODO: store this in the data file.
static const int kSubjectsByLevel[60][3] = {{26, 18, 42, }, {34, 38, 89, }, {22, 33, 72, }, {33, 38, 105, }, {27, 42, 126, }, {20, 40, 118, }, {17, 33, 101, }, {15, 32, 136, }, {16, 35, 119, }, {15, 35, 117, }, {14, 38, 127, }, {11, 37, 129, }, {16, 37, 115, }, {6, 32, 116, }, {7, 33, 100, }, {6, 35, 118, }, {7, 33, 124, }, {8, 29, 135, }, {9, 34, 106, }, {6, 32, 114, }, {7, 32, 108, }, {6, 31, 116, }, {7, 31, 99, }, {7, 31, 121, }, {8, 33, 101, }, {3, 33, 125, }, {8, 32, 107, }, {5, 34, 118, }, {8, 33, 108, }, {6, 31, 103, }, {7, 36, 113, }, {7, 33, 112, }, {5, 32, 103, }, {5, 34, 125, }, {4, 32, 101, }, {7, 33, 98, }, {4, 32, 113, }, {6, 32, 101, }, {8, 34, 101, }, {3, 32, 116, }, {4, 30, 109, }, {5, 33, 98, }, {5, 35, 110, }, {5, 34, 106, }, {3, 35, 98, }, {2, 37, 104, }, {3, 36, 94, }, {3, 37, 105, }, {2, 33, 104, }, {3, 35, 88, }, {1, 35, 77, }, {0, 35, 98, }, {2, 35, 104, }, {0, 35, 115, }, {0, 35, 76, }, {0, 35, 88, }, {2, 35, 93, }, {0, 35, 81, }, {1, 35, 79, }, {1, 32, 65, }, };

static uint32_t ReadUint32(NSFileHandle *file, size_t offset) {
  [file seekToFileOffset:offset];
  NSData *data = [file readDataOfLength:sizeof(uint32_t)];
  return *(uint32_t *)(data.bytes);
}

static uint32_t ReadSubjectOffset(NSFileHandle *file, int subjectID) {
  return ReadUint32(file, (subjectID + 1) * 4);
}

@implementation DataLoader {
  NSFileHandle *_file;
}

- (instancetype)initFromURL:(NSURL *)url {
  if (self = [super init]) {
    NSError *err = nil;
    _file = [NSFileHandle fileHandleForReadingFromURL:url error:&err];
    NSAssert(err == nil, @"Opening data file at %@ failed: %@", url, err);
    
    _count = ReadUint32(_file, 0);
  }
  return self;
}

- (bool)isValidSubjectID:(int)subjectID {
  return subjectID < _count && subjectID >= 0;
}

- (WKSubject *)loadSubject:(int)subjectID {
  NSAssert([self isValidSubjectID:subjectID],
           @"Tried to read subject %d outside 0-%d", subjectID, (int)_count);
  
  const uint32_t offset = ReadSubjectOffset(_file, subjectID);
  
  NSData *data = nil;
  if (subjectID == _count - 1) {
    [_file seekToFileOffset:offset];
    data = [_file readDataToEndOfFile];
  } else {
    // Read the offset of the next subject and compare to determine the length.
    const uint32_t nextOffset = ReadSubjectOffset(_file, subjectID + 1);
    const uint32_t length = nextOffset - offset;
    
    [_file seekToFileOffset:offset];
    data = [_file readDataOfLength:length];
  }
  
  WKSubject *ret = [WKSubject parseFromData:data error:nil];
  ret.id_p = subjectID;
  return ret;
}

- (NSArray<WKSubject *> *)loadAllSubjects {
  NSMutableArray<WKSubject *> *ret = [NSMutableArray array];
  for (int subjectID = 1; subjectID < _count; ++subjectID) {
    [ret addObject:[self loadSubject:subjectID]];
  }
  return ret;
}

- (int)subjectsByLevel:(int)srsLevel byType:(WKSubject_Type)type {
  return kSubjectsByLevel[srsLevel - 1][type - 1];
}

@end
