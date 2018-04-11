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

- (WKSubject *)loadSubject:(int)subjectID {
  NSAssert(subjectID < _count && subjectID >= 0,
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

@end
