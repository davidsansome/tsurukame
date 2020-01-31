An sqlite3 extension to read encoded protobufs in the Tsurukame database dumps.

## Install dependencies:

On mac:

    brew install protobuf
    brew install sqlite3  # The built-in one doesn't support extensions.

## Compile the extension

    make

## Load the extension

On mac:

    /usr/local/opt/sqlite/bin/sqlite3 local-cache.db

On linux

    sqlite3 local-cache.db

Then:

    .load ./proto
    select proto("User", pb) from user;
    select proto("Assignment", pb) from assignments limit 1;

The extension adds a `proto(name, data)` function.  `name` is the name of a
message in wanikani.proto.
