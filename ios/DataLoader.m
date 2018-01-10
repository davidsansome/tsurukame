//
//  DataLoader.m
//  wk
//
//  Created by David Sansome on 23/11/17.
//  Copyright © 2017 David Sansome. All rights reserved.
//

#import "DataLoader.h"

#include <arpa/inet.h>

static uint32_t ReadUint32(NSFileHandle *file, size_t offset) {
  [file seekToFileOffset:offset];
  NSData *data = [file readDataOfLength:sizeof(uint32_t)];
  return *(uint32_t *)(data.bytes);
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
  
  const uint32_t offset = ReadUint32(_file, (subjectID + 1) * 4);
  
  NSData *data = nil;
  if (subjectID == _count - 1) {
    [_file seekToFileOffset:offset];
    data = [_file readDataToEndOfFile];
  } else {
    // Read the offset of the next subject and compare to determine the length.
    const uint32_t nextOffset = ReadUint32(_file, (subjectID + 2) * 4);
    const uint32_t length = nextOffset - offset;
    
    [_file seekToFileOffset:offset];
    data = [_file readDataOfLength:length];
  }
  
  WKSubject *ret = [WKSubject parseFromData:data error:nil];
  ret.id_p = subjectID;
  return ret;
}

@end
