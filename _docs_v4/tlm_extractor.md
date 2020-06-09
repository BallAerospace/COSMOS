---
layout: docs_v4
title: Telemetry Extractor
toc: true
---

This document describes Telemetry Extractor configuration file and command line parameters.

{% cosmos_meta tlm_extractor.yaml %}

## Example File

**Example File: \<Cosmos::USERPATH\>/config/tools/tlm_extractor/tlm_extractor.txt**

{% highlight bash %}
FILL_DOWN
MATLAB_HEADER
DELIMITER ","
SHARE_COLUMNS
DOWNSAMPLE_SECONDS 5
DONT_OUTPUT_FILENAMES
UNIQUE_ONLY
UNIQUE_IGNORE TEMP1
ITEM INST HEALTH_STATUS TIMEFORMATTED
ITEM INST HEALTH_STATUS TEMP1 RAW
ITEM INST HEALTH_STATUS TEMP2 FORMATTED
ITEM INST HEALTH_STATUS TEMP3 WITH_UNITS
ITEM INST HEALTH_STATUS TEMP4
TEXT "Calc" "=D%\*G%" # Calculate TEMP1 (RAW) times TEMP4
{% endhighlight %}

{% cosmos_cmd_line TlmExtractor %}
