# NMSSH

NMSSH is a clean, easy-to-use, unit tested framework for iOS and OSX that wraps libssh2.

Are you using NMSSH for something cool? [Let me know](http://twitter.com/Lejdborg).

## Installation

* Build the framework and add it to your project. Consult the Wiki for detailed information about how to [build for OSX](https://github.com/Lejdborg/NMSSH/wiki/Build-and-use-in-your-OSX-project) or [build for iOS](https://github.com/Lejdborg/NMSSH/wiki/Build-and-use-in-your-iOS-project).
* Add `#include <NMSSH/NMSSH.h>` to your source file.

## What does it look like?

```objc
NMSSHSession *session = [NMSSHSession connectToHost:@"127.0.0.1:22"
                                       withUsername:@"user"];

if (session.isConnected) {
    [session authenticateByPassword:@"pass"];

    if (session.isAuthorized) {
        NSLog(@"Authentication succeeded");
    }
}
    
NSError *error = nil;
NSString *response = [session.channel execute:@"ls -l /var/www/" error:&error];
NSLog(@"List of my sites: %@", response);
    
BOOL success = [session.channel uploadFile:@"~/index.html" to:@"/var/www/9muses.se/"];

[session disconnect];
```

## Documentation

API documentation for NMSSH is available here: [http://docs.9muses.se/nmssh/](http://docs.9muses.se/nmssh/)

## Contributing

* Follow the [code conventions](https://github.com/Lejdborg/cocoa-conventions/).
* Fork NMSSH and create a feature branch. Develop your feature.
* Open a pull request.
* Add your name to the contributor list

**Note:** Make sure that you have documented your code and that you follow the code conventions before opening the pull request.

## Contributors

* [Tommaso Madonia (@Frugghi)](https://github.com/Frugghi)
* [@Shirk](https://github.com/Shirk)

## License

Copyright © 2013 Nine Muses AB

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
