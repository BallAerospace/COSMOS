---
layout: docs_v4
title: Test Runner
toc: true
---

This document describes Test Runner configuration file and command line parameters.

{% cosmos_meta test_runner.yaml %}

### Example File

**Example File: \<Cosmos::USERPATH\>/config/tools/test_runner/test_runner.txt**

{% highlight bash %}
REQUIRE_UTILITY example_test
ALLOW_DEBUG
PAUSE_ON_ERROR TRUE
CONTINUE_TEST_CASE_AFTER_ERROR TRUE
ABORT_TESTING_AFTER_ERROR FALSE
MANUAL TRUE
LOOP_TESTING TRUE
BREAK_LOOP_AFTER_ERROR TRUE
IGNORE_TEST ExampleTest
IGNORE_TEST_SUITE ExampleTestSuite

CREATE_DATA_PACKAGE
COLLECT_META_DATA META DATA

LINE_DELAY 0
MONITOR_LIMITS
PAUSE_ON_RED
{% endhighlight %}

{% cosmos_cmd_line TestRunner %}
