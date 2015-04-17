---
layout: news_item
title: COSMOS BinaryAccessor#write C Extension
date: 2015-04-06 12:00:00 -0700
author: jmthomas
categories: [post]
---

## How I created a COSMOS C Extension

The COSMOS framework has several [C extensions](https://github.com/BallAerospace/COSMOS/tree/master/ext/cosmos/ext) created to increase performance. One critical piece that was created early on is the extension to the [BinaryAccessor](https://github.com/BallAerospace/COSMOS/blob/master/lib/cosmos/packets/binary_accessor.rb) class. This allows for increased performance when reading items from binary packets which is the most common operation in the COSMOS system. I created a COSMOS [performance configuration](https://github.com/BallAerospace/COSMOS/tree/master/test/performance) which spawns 30 fake targets and attempts to send commands to them as fast as possible. Sending commands exercies the write portion of BinaryAccessor and profiling showed this was now becoming a bottleneck. Therefore I set out to port the write method to the existing C extension.

The fact that [Ryan](https://github.com/ryanatball) had already implemented the read method as a C extension gave me a huge head start. I first copied all the Ruby code directly into the C extension so I could try to translate it line by line. Initially if I didn't know how to do the translation I would just comment it out and see how much I could compile. A nice way to do this in C code is use `#if 0 ... #endif`. I also copied the read method signature and locals since the methods are similar. Before I get to far into the guts I should note that this effort relied on a very comprehensive [spec](https://github.com/BallAerospace/COSMOS/blob/master/spec/packets/binary_accessor_spec.rb) or I would have had no idea if I was successful.

Once I implemented the initial parameter checking I dove into the String and Block (binary string) handling portion of the write method. The write method modifies the given buffer by writing a String or Block into it. I started with Google and found [Chris Lalancette's](http://clalance.blogspot.com/2011/01/writing-ruby-extensions-in-c-part-8.html) post and this excellent write-up on [The Ruby C API](http://silverhammermba.github.io/emberb/c). I also cloned [ruby](https://github.com/ruby/ruby) itself and went directly to the [code](https://github.com/ruby/ruby/blob/trunk/string.c). I found the code a little difficult to follow but the important thing to remember is if the method is NOT delcared static then you can use it in your C extension. I ended up using `rb_str_concat` to add to the buffer and `rb_str_update` to directly modify the buffer.

<div class="note warning">
  <h5>Modifying Ruby strings</h5>
  <p>If you directly modify the Ruby string buffer in a C extension with memcpy, memmove, or memset (after getting a pointer with RSTRING_PTR), you need to tell the Ruby runtime with the rb_str_modify method. Calling Ruby's methods like rb_str_update automatically handles this for you.</p>
</div>

Another issue I ran into was the existing Ruby code was calling `to_s` on the input value to ensure it was a String. In the C extension you can check for a type using `RB_TYPE_P(value, T_STRING)` where value is a unknown Ruby VALUE instance and T_STRING can be any number of Ruby types. If the value was not a Ruby String I used `rb_funcall` to directly call the Ruby runtime and call the `to_s` method. If you are unable to find an appropriate method in the C library to do what you want, this is the way to use Ruby from within your C extension.

Next I started to tackle the writing of signed and unsigned integers. COSMOS supports overflow of integers by either truncating a passed in value, saturating to the high or low, or raising an error. So I implemented a `check_overflow` method in C to handle this logic. This code was very difficult to get right because of the size of the values involved. Since COSMOS handles integers of any size, I had to create Ruby Bignum constants to perform the comparisons. This involved another dive into the Ruby source to understand [bignum.c](https://github.com/ruby/ruby/blob/trunk/bignum.c). One of the tricks was to create Ruby Constants up front in the Initialization routine so I wasn't constantly recalulating Bignums for comparison. COSMOS also handles bitfields so those values I generate dynamically using `rb_big_pow` and `rb_bit_minus`. I also created a `TO_BIGNUM` macro which converts Fixnum to Bignum so all the math uses Bignum methods. I could then use the `rb_big_cmp` to compare the given value with the appropriate minimum and maximum values.

The bitfield logic was the most complex to convert to C. This required a lot of C printfs and Ruby puts at each step of the way to ensure all the intermediary calculations were matching up. COSMOS supports big and little endian data buffers so I had to ensure the bytes were reversed and shifted as necessary before finally writing them back to the buffer. Again the `rb_str_modify` function is called to notify the Ruby runtime that the buffer has been changed.

The floating point values were probably the easiest because I simply called `RFLOAT_VALUE(value)` to get the double value of the passed in Ruby value. At this point I was able to successfully run the full spec. However, once I ran the entire COSMOS spec suite I hit a failure on a simple write call in api_spec.rb. I determined the spec was trying to send an integer value where there was a floating point value defined. The old Ruby code simply converted this value inline but I was calling `RFLOAT_VALUE(value)` which ASSUMES the value is a float. I updated the binary_accessor_spec.rb to capture this failure and also noted a similar issue in the integer logic. The Ruby code was calling `value = Integer(value)` for integers and `value = Float(value)` for floats. This not only handles the case of passing an integer value when you want to write a float, it also handles truncating a float to an integer and even handles parsing a String which contains a numeric value. When you have a tremendous amount of work being done by Ruby you are best to fall back to `rb_funcall`. But how to call the `Integer()` method which doesn't appear to have a receiver. Remember that if a method doesn't appear to have a receiver it's probably being called on Kernel which is [exactly the case](http://www.rubydoc.info/stdlib/core/Kernel#Integer-instance_method). Thus I call it with `value = rb_funcall(rb_mKernel, rb_intern("Float"), 1, value);`. (NOTE: I also discovered I could call the method passing 'self' instead of rb_mKernel but using Kernel felt more explicit).

At this point I refactored to combine some of the functionality in the read method with the new write method. I probably could have done more refactoring but refactoring C code just isn't as much fun as refactoring Ruby code. Once I completed the refactor I wanted to benchmark my new C extension to determine how much faster (or slower?) I made it. I love the [benchmark-ips](https://github.com/evanphx/benchmark-ips) gem as it benchmarks iterations per second and automatically determines how many times to run the code to get good data. But I didn't want to re-write our existing specs to support using this gem so I looked into how to integrate it with RSpec. It turns out this is all that was needed in our spec_helper.rb:

```if ENV.key?("BENCHMARK")
    c.around(:each) do |example|
      Benchmark.ips do |x|
        x.report(example.metadata[:full_description]) do
          example.run
        end
      end
    end
  end
```

Benchmark-ips works by calculating the number of runs to get interesting data and then running the code in question. Thus defining BENCHMARK in the environment makes the specs run EXTREMELY slow. I used the ability of RSpec to filter only the examples I wanted to benchmark with the -e option:

```rspec spec/packets/binary_accesor_spec.rb -e "write only"```

Running this in master and then in my C-extension branch I calculated the difference in iterations and then filtered out all the "complains" (raise an exception) and "overflow" test cases to focus on just the tests which write values. The average improvement was 1.3x. Not quite as awesome as I was hoping for but an improvement in an area that is performance sensitive. I suspected I could get additional performance if I optimized the check_overflow method to not always use Bignums and to do Fixnum comparisons if possible. However, this did not yield any optimizations so I backed out the change.

At this point I submitted the [pull request](https://github.com/BallAerospace/COSMOS/pull/103) which broke the Travis build. [Ryan](https://github.com/ryanatball) then added a patch that corrected all my issues and the build passed. I re-benchmarked his changes and overall the results were actually slightly faster on average so the pull request was merged.

Enjoy a faster COSMOS write routine!

