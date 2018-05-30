
Thread Pool library for iOS
===========================

The thread pool and URL dispatch library used by Lightstreamer's iOS client library since version 1.2.


What this library does
----------------------

This code was originally written in 2012 to address a specific problem of the iOS SDK and runtime:

* `NSURLConnection` on iOS had a limit of 4 concurrent connections to the same end-point. 
  Above this limit, connections would simply timeout without even trying.

In the meantime, the `NSURLConnection` API has been replaced with the more configurable `NSURLSession`,
but the problem is still there: a default `NSURLSession` on iOS has 4 as its maximum connections per host,
and a request in excess will stil timeout. In theory, you could raise the `HTTPMaximumConnectionsPerHost` parameter,
but official documentation states:

> Additionally, depending on your connection to the Internet, a session may use a lower limit than the one you specify.

This library solves the problem by keeping the number of submitted URL requests under control
for each end-point, ensuring that a request in excess is enqueued and not sent through the system.
The library also offers methods to know in advance when a request is going to succeed or put on wait.
Last but not least, the library enforces the timeout set in the URL request.

The original article that described the problem in available on Lightstreamer's blog:

* [blog.lightstreamer.com/2013/01/on-ios-url-connection-parallelism-and.html](http://blog.lightstreamer.com/2013/01/on-ios-url-connection-parallelism-and.html)

What is included in this library:

* `LSURLDispatcher`: a singleton class to keep the number of concurrent connections under control.

* `LSThreadPool`: a fixed thread pool implementation with thread recycling and collection.

* `LSTimerThread`: bonus class to run timed invocations without using the main thread.

* `LSLog`: simple logging facility used internally by previous classes.
  

LSURLDispatcher
---------------

The `LSURLDispatcher` is a singleton and is able to automatically initialize itself. Use it to
start an URL request toward and end-point in one of 3 possible ways:

* **Synschronous request**: in this case, the dispatcher will download the request URL
and deliver it as a NSData. If the end-point is already at its connection limit,
the caller will wait until a connection is freed.

* **Short request**: the dispatcher will asynchronously connect and send events to your
delegate as the connection proceeds. If the end-point is already at its connection limit,
the dispatcher will wait in the background until a connection is freed. Use short requests
for short-lived operations that are expected to last a few seconds only.

* **Long request**: the dispatcher will asynchronously connect only if the end-point is below 
a specific limit (lower than the connection limit), otherwise it will react according to a specified
policy (by default it will throw an exception, but other policies are available). Use long requests for 
long-lived operations expected to last for minutes or more (data streaming, audio/video streaming, VoIP, etc.).

The distinction between **short- and long-lived requests** is important: an app that opens 4 long-lived
requests to the same end-point, such as audio, video and data streams, has no way to contact the same end-point 
again until one of the requests is terminated, even for simple requests like downloading an icon. By keeping
short- and long-lived requests separated and with different limits, the library ensures that short-lived requests
have always some spare connections to use. The Lightstreamer client takes advantage of this distinction by running 
stream connections as long-lived requests and control connections as short-lived requests.

To start a short-lived request simply do:

```objective-c
NSURL *url= [NSURL URLWithString:@"http://some/url"];
NSURLRequest *req= [NSURLRequest requestWithURL:url];

LSURLDispatchOperation *op= [[LSURLDispatcher sharedDispatcher] dispatchShortRequest:req delegate:self];
```

A request operation may be canceled at a later time, if necessary:

```objective-c
[op cancel];
```

With long-lived requests you can also check in advance if it is going to succeed
or not (that is, if the limit has been reached or not):

```objective-c
if (![[LSURLDispatcher sharedDispatcher] isLongRequestAllowed:req]) {
NSLog(@"Connection limit reached");

} else {
LSURLDispatchOperation *longOp= [[LSURLDispatcher sharedDispatcher] dispatchLongRequest:req delegate:self];
// ...
}
```

Starting with **version 1.7.0** request operations are executed on `NSURLSession` threads. The library now uses 
its own thread pools only to enqueue requests in excess and decoupling the delivery of delegate events.

Starting with **verison 1.8.0** the library uses GCD queues to enqueue requests in excess and decoupling the delivery of delegate events.
Thread pools remain available as part of the library but are no more used by the `LSURLDispatcher`.


LSThreadPool
------------

Use of `LSThreadPool` is really simple. Create it with a defined size and name (name 
will be used for logging):

```objective-c
// Create the thread pool
LSThreadPool *threadPool= [[LSThreadPool alloc] initWithName:@"Test" size:4];
```
	
Then, schedule invocations with its `scheduleInvocationForTarget:selector:` or 
`scheduleInvocationForTarget:selector:withObject:` methods. E.g.,

```objective-c
[threadPool scheduleInvocationForTarget:self selector:@selector(addOne)];
```

If you want something more handy you can use blocks. E.g.,

```objective-c
[threadPool scheduleInvocationForBlock:^() {
    // Do something
}];
```

Finally, dispose of the thread pool before releasing it when done:

```objective-c
[threadPool dispose];
threadPool= nil;
```

Threads are recycled if another scheduled call arrives within 10 seconds. After 15 seconds
a collector removes idle threads.


LSTimerThread
-------------

The `LSTimerThread` provides delayed calls to any method of any object, without using the main thread.
A shared thread is used to schedule calls, so make sure your called methods do not take too much time
to execute.

To use the timer just schedule the call as you would do with `performSelector:withArgument:afterDelay`
of `NSObject`. E.g.,

```objective-c
[[LSTimerThread sharedTimer] performSelector:@selector(timeout) onTarget:self afterDelay:timeout];
````

If you want something more handy you can use blocks. E.g.,

```objective-c
[[LSTimerThread sharedTimer] performBlock:^() {
    // Do something
} afterDelay:timeout];
```


LSLog
-----

The `LSLog` provides simple logging for separable sources. No logging levels are supported, but a logging
delegation is provided through the `LSLogDelegate` protocol.

Supported sources are:

* `LOG_SRC_THREAD_POOL` for `LSThreadPool`
* `LOG_SRC_URL_DISPATCHER` for `LSURLDispatcher`
* `LOG_SRC_TIMER` for `LSTimerThread`

All logging may be considered of DEBUG level, so enable a source only if you need to debug it:

```objective-c
[LSLog enableSource:LOG_SRC_THREAD_POOL];
````

To enable delegation just set your `LSLogDelegate` implemenation on the `LSLog` class:

```objective-c
[LSLog setDelegate:myLogger];
````


Test cases
----------

A few simple test cases are included. They show the strict enforcement on thread pool size,
the timed invocations and the connection limit per end-point.


License
-------

This software is part of Lightstreamer's iOS client library since version 1.2. It is released
as open source under the Apache License 2.0. See LICENSE for more information.
