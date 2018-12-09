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

@implementation DataLoader {
  NSFileHandle *_file;
  uint32_t _firstSubjectOffset;
  TKMDataFileHeader *_header;
}

- (instancetype)initFromURL:(NSURL *)url {
  if (self = [super init]) {
    NSError *err = nil;
    _file = [NSFileHandle fileHandleForReadingFromURL:url error:&err];
    NSAssert(err == nil, @"Opening data file at %@ failed: %@", url, err);

    // Read the header.
    uint32_t headerLength = ReadUint32(_file, 0);
    _firstSubjectOffset = 4 + headerLength;
    NSData *headerData = [_file readDataOfLength:headerLength];
    _header = [TKMDataFileHeader parseFromData:headerData error:&err];
    NSAssert(err == nil, @"Reading data file header failed: %@", err);
  }
  return self;
}

- (int)maxSubjectLevel {
  return (int)_header.subjectsByLevelArray_Count;
}

- (GPBInt32Array *)deletedSubjectIDs {
  return _header.deletedSubjectIdsArray;
}

- (int)maxLevelGrantedBySubscription {
  if (_maxLevelGrantedBySubscription) {
    return MIN(_maxLevelGrantedBySubscription, self.maxSubjectLevel);
  }
  return self.maxSubjectLevel;
}

- (bool)isValidSubjectID:(int)subjectID {
  return subjectID < _header.subjectByteOffsetArray_Count && subjectID >= 0;
}

- (nullable TKMSubject *)loadSubject:(int)subjectID {
  NSAssert([self isValidSubjectID:subjectID], @"Tried to read subject %d outside 0-%d", subjectID,
           (int)_header.subjectByteOffsetArray_Count);

  const uint32_t offset =
      _firstSubjectOffset + [_header.subjectByteOffsetArray valueAtIndex:subjectID];

  NSData *data = nil;
  if (subjectID == _header.subjectByteOffsetArray_Count - 1) {
    [_file seekToFileOffset:offset];
    data = [_file readDataToEndOfFile];
  } else {
    // Read the offset of the next subject and compare to determine the length.
    const uint32_t nextOffset =
        _firstSubjectOffset + [_header.subjectByteOffsetArray valueAtIndex:subjectID + 1];
    const uint32_t length = nextOffset - offset;

    [_file seekToFileOffset:offset];
    data = [_file readDataOfLength:length];
  }

  TKMSubject *ret = [TKMSubject parseFromData:data error:nil];
  if (ret.level > self.maxLevelGrantedBySubscription) {
    NSLog(@"Tried to load subject %d from level %d > max level %d",
          subjectID, ret.level, self.maxLevelGrantedBySubscription);
    return nil;
  }
  ret.id_p = subjectID;
  return ret;
}

- (NSArray<TKMSubject *> *)loadAllSubjects {
  NSMutableArray<TKMSubject *> *ret = [NSMutableArray array];
  for (int subjectID = 1; subjectID < _header.subjectByteOffsetArray_Count; ++subjectID) {
    TKMSubject *subject = [self loadSubject:subjectID];
    if (subject) {
      [ret addObject:subject];
    }
  }
  return ret;
}

- (nullable TKMSubjectsByLevel *)subjectsByLevel:(int)level {
  if (level > self.maxLevelGrantedBySubscription) {
    return nil;
  }
  return _header.subjectsByLevelArray[level - 1];
}

@end
