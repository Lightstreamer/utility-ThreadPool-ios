Pod::Spec.new do |s|


  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.name         = "LSThreadPoolLib"
  s.version      = "1.6.5"
  s.summary      = "Lightstreamer Thread Pool and URL Dispatch Library"

  s.description  = <<-DESC
                   This library addresses the limited size of the connection
                   pool of iOS. For more background information on this issue
                   please see:

                   * http://blog.lightstreamer.com/2013/01/on-ios-url-connection-parallelism-and.html

                   The library contains the following utility classes:

                   * LSURLDispatcher: provides services to connect to a URL,
                   synchronously and asynchronously, while ensuring the
                   connection pool is never exceeded.
                   * LSThreadPool: a general purpose fixed-size thread pool
                   implementation. Used by LSURLDispatcher but available for
                   other uses.
                   * LSTimerThread: a service to perform delayed calls to
                   target/selector without employing the main thread. Used by
                   LSURLDispatcher but available for other uses.
                   DESC

  s.homepage     = "https://github.com/Lightstreamer/utility-ThreadPool-ios"


  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.license      = { :type => "Apache License, Version 2.0",
                     :file => "LICENSE" }


  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the authors of the library, with email addresses. Email addresses
  #  of the authors are extracted from the SCM log. E.g. $ git log. CocoaPods also
  #  accepts just a name if you'd rather not provide an email address.
  #
  #  Specify a social_media_url where others can refer to, for example a twitter
  #  profile URL.
  #

  s.author              = { "Gianluca Bertani" => "gianluca.bertani@lightstreamer.com" }
  s.social_media_url    = "https://twitter.com/self_vs_this"


  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.ios.deployment_target = "6.0"
  s.osx.deployment_target = "10.7"
  s.tvos.deployment_target = "9.0"


  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.source       = { :git => "https://github.com/Lightstreamer/utility-ThreadPool-ios.git",
                     :tag => s.version.to_s }


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.source_files  = "Lightstreamer Thread Pool Library/**/*.{h,m}"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.requires_arc = true
  s.xcconfig = { "OTHER_LDFLAGS" => "-ObjC" }

end
