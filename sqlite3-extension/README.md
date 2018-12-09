An sqlite3 extension to read encoded protobufs in the Tsurukame database dumps.

## Compile the extension

    make

## Load the extension

    sqlite3 local-cache.db
    .load ./proto
    select proto("User", pb) from user;
    select proto("Assignment", pb) from assignments limit 1;

The extension adds a `proto(name, data)` function.  `name` is the name of a
message in wanikani.proto.
