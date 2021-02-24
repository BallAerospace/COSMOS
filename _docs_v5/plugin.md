---
layout: docs
title: Plugin Configuration
toc: true
---

This document provides the information necessary to configure a COSMOS plugin. Plugins are used to include COSMOS targets (typically one per plugin) and any associated processes.

Configuration file formats for the following are provided:

- plugin.txt

# Plugin Configuration

Each plugin is built as a Ruby gem and thus has a <plugin>.gemspec file which builds it. Plugins have a plugin.txt file which declares all the variables used by the plugin and how to interface to the target(s) it contains.

<div class="note unreleased">
  <p>Additional information about building, upgrading, and releasing plugins needed.</p>
</div>

{% cosmos_meta plugin.yaml %}
