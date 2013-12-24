Pod::Spec.new do |s|
  s.name         = "NMSSH"
  s.version      = "1.1.0"
  s.summary      = "Log4j port for iOS and Mac OS X."
  s.homepage     = "NMSSH is a clean, easy-to-use, unit tested framework for iOS and OSX that wraps libssh2."
  s.license      = 'MIT'
  s.author       = { "Tommaso Madonia" => "", "@Shirk" => "", "Endika Gutiérrez" => "me@endika.net" }

  # https://github.com/Lejdborg/NMSSH.git
  # uses endSly repository for testing.

  s.source       = { :git => "https://github.com/endSly/NMSSH.git", :tag => s.version.to_s }
  s.source_files = 'NMSSH-iOS', 'NMSSH-iOS/Libraries/include/libssh2/*.h', 'NMSSH-iOS/Libraries/include/openssl/*.h', 'NMSSH', 'NMSSH/**/*.{h,m}' 
  s.requires_arc = true
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'

  s.libraries      = 'ssl', 'ssh2', 'crypto'

  #s.ios.source_files = 'NMSSH-iOS/**/*.h'

  s.xcconfig = {
    "OTHER_LDFLAGS" => "-ObjC",
    "LIBRARY_SEARCH_PATHS" => '"$(PODS_ROOT)/NMSSH-iOS/Libraries/lib"'
  }

end
