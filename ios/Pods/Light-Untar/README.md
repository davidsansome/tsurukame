# Light Untar for iOS
## Purpose
### Why this code?
http://blog.octo.com/en/untar-on-ios-the-pragmatic-way/

### What this code will do:
* Extract files and directories created with the tar -cf command
* Work with 512 block or multiple (tar -b512 or just tar)

### What this code will not do:
* Extract compressed files and directories created with the tar -czf command
* Work with unix right and ownership
* Work with no standard block size
	
##How to use
``` objective-c
NSData* tarData = [NSData dataWithContentsOfFile:@"/path/to/your/tar/file.tar"];
NSError *error;
[[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:@"/path/to/your/extracted/files/" withTarData:tarData error:&error];
```
Remember that you can't write outside your app directory