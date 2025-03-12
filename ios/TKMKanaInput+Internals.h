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

#ifndef TKMKanaInput_Internals_h
#define TKMKanaInput_Internals_h

static const unichar kDistanceHiraganaKatakanaCodeblock = u'ア' - u'あ';
static const unichar kHiraganaMax = u'\u309f';
static const unichar kHiraganaMin = u'\u3040';

static NSDictionary<NSString *, NSString *> *kReplacements;
static NSCharacterSet *kVowels;
static NSCharacterSet *kConsonants;
static NSCharacterSet *kN;
static NSCharacterSet *kCanFollowN;
static dispatch_once_t sOnceToken;

extern void EnsureInitialised(void);

#endif
