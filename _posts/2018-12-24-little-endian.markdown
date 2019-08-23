---
layout: news_item
title: 'Little Endian Packet Data'
date: 2018-12-24 08:00:00 -0700
author: ryanmelt
categories: [post]
---

APPEND does not work with little endian bitfields.

Defining little endian bitfields is a little weird but does work in COSMOS.

Rules on how COSMOS handles LITTLE_ENDIAN data:

1. COSMOS bit offsets are always defined in BIG_ENDIAN terms. Bit 0 is always the most significant bit of the first byte in a packet, and increasing from there.

1. All 8, 16, 32, and 64-bit byte-aligned LITTLE_ENDIAN data types define their bit_offset as the most significant bit of the first byte in the packet that contains part of the item. (This is exactly the same as BIG_ENDIAN). Note that for all except 8-bit LITTLE_ENDIAN items, this is the LEAST significant byte of the item.

1. LITTLE_ENDIAN bit fields are defined as any LITTLE_ENDIAN INT or UINT item that is not 8, 16, 32, or 64-bit and byte aligned.

1. LITTLE_ENDIAN bit fields must define their bit_offset as the location of the most significant bit of the bitfield in BIG_ENDIAN space as described in rule 1 above. So for example. The following C struct at the beginning of a packet would be defined like so:

```
struct {
  unsigned short a:4;
  unsigned short b:8;
  unsigned short c:4;
}

ITEM A 4 4 UINT "struct item a"
ITEM B 12 8 UINT "struct item b"
ITEM C 8 4 UINT "struct item c"
```

This is hard to visualize, but the structure above gets spread out in a byte array like the following after byte swapping: least significant 4 bits of b, 4-bits a, 4-bits c, most significant 4 bits of b
