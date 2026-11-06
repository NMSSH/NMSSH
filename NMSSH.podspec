Pod::Spec.new do |s|
    s.name         = "NMSSH"
    s.version      = "2.3.1"
    s.summary      = "NMSSH is a clean, easy-to-use, unit tested framework for iOS and OSX that wraps libssh2."
    s.description  = "NMSSH is a clean, easy-to-use,unit tested framework for iOS and OSX that wraps libssh2."
    s.homepage     = "https://github.com/NMSSH/NMSSH"
    s.license      = { :type => 'MIT', :file => 'LICENSE.md' }
    s.author       = { "Christoffer Lejdborg" => "hello@9muses.se", "Tommaso Madonia" => "tommaso@madonia.me" }
    s.source       = { :git => "https://github.com/pavlo-kravchenko/NMSSH.git", :branch => "modern-libssh2" }
    s.requires_arc = true
    
    s.ios.deployment_target = "15.0"
    s.osx.deployment_target = "12.0"
    
    # Fresh libssh2 1.11.1 + OpenSSL 3.5.9 static libraries (fixes the
    # double-free crash in libssh2 1.9.0 packet handling).
    # XCFrameworks are retained by CocoaPods and resolved per platform
    # (device arm64 / simulator x86_64+arm64) automatically.
    s.ios.vendored_xcframeworks = [
        "NMSSH-iOS/Libraries/xcfs/ssh2.xcframework",
        "NMSSH-iOS/Libraries/xcfs/ssl.xcframework",
        "NMSSH-iOS/Libraries/xcfs/crypto.xcframework",
    ]
    
    s.source_files       = ["NMSSH", "NMSSH/**/*.{h,m}"]
    s.public_header_files = ["NMSSH/*.h", "NMSSH/Protocols/*.h", "NMSSH/Config/NMSSHLogger.h"]
    s.private_header_files = ["NMSSH/Config/NMSSH+Protected.h", "NMSSH/Config/socket_helper.h"]
    
    s.frameworks = "CFNetwork"
    
    s.pod_target_xcconfig = {
        'OTHER_LDFLAGS' => '-ObjC -lz',
        'HEADER_SEARCH_PATHS' => '"$(PODS_XCFRAMEWORKS_BUILD_DIR)/ssh2/ssh2.framework/Headers"',
    }
    
    s.ios.source_files = ["NMSSH-iOS", "NMSSH-iOS/Libraries/**/*.h"]
    s.ios.public_header_files = "NMSSH-iOS/Libraries/**/*.h"
    
    s.osx.source_files = ["NMSSH-OSX", "NMSSH-OSX/Libraries/**/*.h"]
    s.osx.public_header_files = "NMSSH-OSX/Libraries/**/*.h"
    s.osx.pod_target_xcconfig = {
        'OTHER_LDFLAGS' => '-ObjC',
        'LIBRARY_SEARCH_PATHS' => "$(SRCROOT)/NMSSH-OSX/Libraries/lib",
    }
end
