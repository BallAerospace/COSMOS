---
layout: news_item
title: 'Require vs Load'
date: 2017-11-13 09:00:00 -0700
author: jmthomas
categories: [post]
---
As a COSMOS developer I often get asked about require vs load vs require_utility vs load_utility and what do they all mean. Let me explain these keywords and how they are used within Ruby and COSMOS.

### Require vs Load

The Ruby programming language defines the keywords 'require' and 'load'. These are actually methods on the Kernel class and you can find the full documention on [ruby-doc.org](https://ruby-doc.org/) for both [require](https://ruby-doc.org/core-2.4.2/Kernel.html#method-i-require) and [load](https://ruby-doc.org/core-2.4.2/Kernel.html#method-i-load). They basically include additional Ruby source files into the current execution environment so they can be used by your code. The key difference is that require will only include a file once. If you try to require a file a second time the require method actually returns false indicating that the file has already been required. You can easily test this by opening an IRB session and requiring something twice.

```
irb(main):001:0> require 'cosmos'
=> true
irb(main):002:0> require 'cosmos'
=> false
```

This has key implications for usage in COSMOS, especially when writing scripts for use in Script Runner or Test Runner. Let's say you have a subroutine that you want to call (and don't want to watch the line by line execution of). You require it in your script and execute it. You realize you have a bug in this required script and edit the file. Now you re-run the top level script but notice none of your changes have been include! What gives?! The require keyword notices that you've already required the file and thus does not re-load it on the next execution of your script. This has led some COSMOS users to simply close and re-open Script Runner or Test Runner each time they edit something. While this solves the require problem there is a better solution: load.

The load keyword loads the specified file everytime and thus reparses any changes that may have been made to the file in question. This is almost always what you want to use when writing scripts for COSMOS as it allows you to edit files and be assured that you will be running the latest. Note the difference when using load in this IRB session.

```
irb(main):001:0> load 'cosmos.rb'
=> true
irb(main):002:0> load 'cosmos.rb'
=> true
irb(main):003:0> load 'cosmos'
LoadError: cannot load such file -- cosmos
        from (irb):3:in `load'
        from (irb):3
        from C:/Ruby233p222-x64/bin/irb.cmd:19:in `<main>'
irb(main):004:0> require 'cosmos.rb'
=> true
```

When using the keyword load you must add the .rb Ruby extension to the file you are trying to load. Leaving this off (which is allowed with the require keyword) will result in a LoadError as shown above. Note that require works with or without the .rb Ruby extension and that the previous load of cosmos.rb did not affect the require of cosmos.rb (it still had never been required).

### Load vs load_utility

Now that we've established how the require and load keywords work in Ruby, how does the load_utility keyword work in COSMOS? This keyword is COSMOS specific and means that COSMOS will step through the included source file when it is called. This is useful for debugging subroutines or for things that you simply want to watch execute. It is not recommended for subroutines that take an extended time to process like looping over large datasets. This will SIGNIFICANTLY slow down the execution of this code as it shows each line execute in the GUI.

Note that COSMOS also has a require_utility keyword. This keyword works exactly like load_utility which is why we recommend using load_utility going forward as it better matches the Ruby keywords in what it is doing. This keyword is effectively deprecated and may be removed in future versions of COSMOS.

### Ruby Load Path

After talking aobut require and load I think this is a good place to talk a little about the Ruby Load Path since it directly affects whether a require or load will succeed. The overall Ruby load path can be found by typing $LOAD_PATH. Doing this in my IRB session running Ruby 2.3.3 results in the following.

```
irb(main):004:0> puts $LOAD_PATH
C:\git\cosmos\lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/did_you_mean-1.0.0/lib
C:/Ruby233p222-x64/lib/ruby/site_ruby/2.3.0
C:/Ruby233p222-x64/lib/ruby/site_ruby/2.3.0/x64-msvcrt
C:/Ruby233p222-x64/lib/ruby/site_ruby
C:/Ruby233p222-x64/lib/ruby/vendor_ruby/2.3.0
C:/Ruby233p222-x64/lib/ruby/vendor_ruby/2.3.0/x64-msvcrt
C:/Ruby233p222-x64/lib/ruby/vendor_ruby
C:/Ruby233p222-x64/lib/ruby/2.3.0
C:/Ruby233p222-x64/lib/ruby/2.3.0/x64-mingw32
=> nil
```

You'll notice most of these paths are relative to my Ruby installation at C:/Ruby233p222. I also have an entry for my developer copy of COSMOS due to my environment variable of RUBYLIB=C:\git\cosmos\lib. As a COSMOS developer I have this variable set but you most likely will not. Setting the RUBYLIB environment variable is useful when developing but can interfere with loading gems since it is at the top of the $LOAD_PATH.

When you start requiring other libraries they typically add things to your LOAD_PATH. Watch what happens when I require 'cosmos'.

```
irb(main):001:0> require 'cosmos'
=> true
irb(main):002:0> puts $LOAD_PATH
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/uuidtools-2.1.5/lib
C:\git\cosmos\lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/did_you_mean-1.0.0/lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/bundler-1.15.4/lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/json-1.8.6/lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/extensions/x64-mingw32/2.3.0/json-1.8.6
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rack-2.0.3/lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/puma-3.10.0/lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/extensions/x64-mingw32/2.3.0/puma-3.10.0
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/uuidtools-2.1.5/lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/mini_portile2-2.3.0/lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/nokogiri-1.8.1-x64-mingw32/lib
C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rubyzip-1.1.7/lib
C:/Ruby233p222-x64/lib/ruby/site_ruby/2.3.0
C:/Ruby233p222-x64/lib/ruby/site_ruby/2.3.0/x64-msvcrt
C:/Ruby233p222-x64/lib/ruby/site_ruby
C:/Ruby233p222-x64/lib/ruby/vendor_ruby/2.3.0
C:/Ruby233p222-x64/lib/ruby/vendor_ruby/2.3.0/x64-msvcrt
C:/Ruby233p222-x64/lib/ruby/vendor_ruby
C:/Ruby233p222-x64/lib/ruby/2.3.0
C:/Ruby233p222-x64/lib/ruby/2.3.0/x64-mingw32
=> nil
```

Now a bunch of gems have added themselves to my $LOAD_PATH. These gems are the gems that cosmos has dependencies on. Note that when you require or load a file the $LOAD_PATH entries are searched in order. Thus in the above example a file in the uuidtools library will be found before a file in the rubyzip library.

You can display your $LOAD_PATH from Script Runner by simply running "puts $LOAD_PATH" from Script Runner. When I do this I get the following in my Script Output:

```
2017/11/13 10:58:21.815 (SCRIPTRUNNER): Starting script:
2017/11/13 10:58:22.076 (:1): C:/git/COSMOS/demo/procedures
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/uuidtools-2.1.5/lib
2017/11/13 10:58:22.076 (:1): C:/git/COSMOS/demo/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/bundler-1.15.4/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/ruby-prof-0.15.9/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/extensions/x64-mingw32/2.3.0/ruby-prof-0.15.9
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/roodi-4.1.1/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/reek-1.6.6/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/unparser-0.2.4/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rainbow-2.2.2/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/extensions/x64-mingw32/2.3.0/rainbow-2.2.2
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/procto-0.0.3/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/parser-2.2.3.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/guard-rspec-4.7.3/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rspec-3.5.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rspec-mocks-3.5.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rspec-expectations-3.5.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rspec-core-3.5.4/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rspec-support-3.5.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/guard-bundler-2.1.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/guard-compat-1.2.1/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/guard-2.14.1/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/notiffany-0.1.1/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/shellany-0.0.1/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/nenv-0.3.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/lumberjack-1.0.12/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/listen-2.10.1/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rb-inotify-0.9.10/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rb-fsevent-0.10.2/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/formatador-0.2.5/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/flog-4.6.1/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/flay-2.10.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/ruby_parser-3.10.1/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/sexp_processor-4.10.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/path_expander-1.0.2/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/ffi-1.9.18-x64-mingw32/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/erubis-2.7.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/diff-lcs-1.2.5/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/coveralls-0.8.21/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/thor-0.19.4/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/term-ansicolor-1.6.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/tins-1.15.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/simplecov-0.14.1/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/simplecov-html-0.10.2/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/docile-1.1.5/lib
2017/11/13 10:58:22.076 (:1): C:/git/COSMOS/lib
2017/11/13 10:58:22.076 (:1): C:/git/extensions/x64-mingw32/2.3.0/cosmos-0.0.0
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/uuidtools-2.1.5/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/snmp-1.2.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rubyzip-1.1.7/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rdoc-4.3.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rack-2.0.3/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/qtbindings-4.8.6.3-x64-mingw32/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/qtbindings-qt-4.8.6.3-x64-mingw32/qtlib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/puma-3.10.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/extensions/x64-mingw32/2.3.0/puma-3.10.0
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/pry-doc-0.6.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/yard-0.9.9/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/pry-0.10.4/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/slop-3.6.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/method_source-0.8.2/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/opengl-0.9.2-x64-mingw32/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/nokogiri-1.8.1-x64-mingw32/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/mini_portile2-2.3.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/json-1.8.6/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/extensions/x64-mingw32/2.3.0/json-1.8.6
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/httpclient-2.8.3/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/concord-0.1.5/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/equalizer-0.0.11/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/coderay-1.1.2/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/celluloid-0.16.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/timers-4.0.4/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/hitimes-1.2.6/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/extensions/x64-mingw32/2.3.0/hitimes-1.2.6
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/benchmark-ips-2.7.2/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/ast-2.3.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/adamantium-0.2.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/memoizable-0.4.2/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/thread_safe-0.3.6/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/ice_nine-0.11.2/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/abstract_type-0.0.7/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/rake-12.1.0/lib
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/site_ruby/2.3.0
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/site_ruby/2.3.0/x64-msvcrt
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/site_ruby
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/vendor_ruby/2.3.0
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/vendor_ruby/2.3.0/x64-msvcrt
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/vendor_ruby
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/2.3.0
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/2.3.0/x64-mingw32
2017/11/13 10:58:22.076 (:1): C:/Ruby233p222-x64/lib/ruby/gems/2.3.0/gems/qtbindings-4.8.6.3-x64-mingw32/lib/../lib/2.3
2017/11/13 10:58:22.076 (:1): C:/git/COSMOS/demo/config/targets/INST/lib
2017/11/13 10:58:22.076 (:1): C:/git/COSMOS/demo/config/targets/INST/procedures
2017/11/13 10:58:22.076 (:1): C:/git/COSMOS/demo/config/targets/EXAMPLE/lib
2017/11/13 10:58:22.076 (:1): C:/git/COSMOS/demo/config/targets/TEMPLATED/lib
2017/11/13 10:58:22.076 (:1): C:/git/COSMOS/demo/config/targets/SYSTEM/lib
2017/11/13 10:58:22.092 (SCRIPTRUNNER): Script completed:
```

Wow, that is a lot of gems! COSMOS requires a lot of libraries to support how it operates including many used for development purposes like rspec and simplecov. An important thing to note is at the top of the list the following paths are listed.

```
C:/git/COSMOS/demo/procedures
C:/git/COSMOS/demo/lib
```

The first path is due to the following line in the COSMOS Demo configuration's system.txt configuration file: ```PATH PROCEDURES ./procedures```. This adds the procedures directory in the current COSMOS configuration (C:/git/COSMOS/demo on my machine) to the path.

The second path is added to every COSMOS configuration. The lib directory in the current COSMOS configuration (C:/git/COSMOS/demo on my machine).

You should also note the last few lines of the $LOAD_PATH.

```
C:/git/COSMOS/demo/config/targets/INST/lib
C:/git/COSMOS/demo/config/targets/INST/procedures
C:/git/COSMOS/demo/config/targets/EXAMPLE/lib
C:/git/COSMOS/demo/config/targets/TEMPLATED/lib
C:/git/COSMOS/demo/config/targets/SYSTEM/lib
```

These are added because COSMOS automatically adds the lib and procedures directory from each Target folder. Thus you are able to directly load a file in the INST/procedures directory by doing "load 'checks.rb'" (for example). If a file is in a subdirectory like the INST/procedures/utilities directory, then you must specify the additional subpath such as "load_utility 'utilities/clear.rb'".

### require_relative

Just for completeness note that there is also a Ruby keyword called [require_relative](https://ruby-doc.org/core-2.4.2/Kernel.html#method-i-require_relative). This works similar to require but instead of using the LOAD_PATH as described above, it looks relative to the current executing file. This should rarely be needed in COSMOS except perhaps in test files.

If you have a question which would benefit the community or find a possible bug please use our [Github Issues](https://github.com/BallAerospace/COSMOS/issues). If you would like more information about a COSMOS training or support contract please contact us at <cosmos@ball.com>.
