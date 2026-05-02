# Rationale — MOFORMAT

## Motivation

At the time, MO (magneto-optical) drives were becoming a popular new storage device.

I purchased one as soon as it became available.\
Although I already had a hard disk, the idea of a removable medium with around 120MB capacity felt like a very practical and appealing solution.

The device itself worked well, but one issue quickly became apparent:

**Formatting took far too long.**

The standard OS formatter always performed a full physical format.\
For a 120MB disk, this took around 15 minutes.

Since the system was single-tasking, there was nothing to do but wait.

---

## Initial Idea

MO media is already physically formatted when purchased.

So the idea was straightforward:

> If only logical formatting were performed, the process should be much faster.

However, there was a problem.

The structure of the management area on MO media was not publicly documented at the time.\
While FAT structures for floppy disks were widely available, information for larger-capacity media such as MO disks was difficult to obtain.

As a result, this idea remained unrealized for some time.

---

## Breakthrough

At some point, a simple idea emerged:

> Copy the management area from an already formatted MO disk.

Instead of reconstructing the format structure from specifications,\
it would be possible to duplicate a known-good formatted layout.

This approach has limitations — for example, it does not support creating multiple partitions within a single disk.\
However, for personal usage, this was not a problem.

If necessary, the standard OS formatter could still be used.

---

## Result

A prototype was implemented quickly.

The result exceeded expectations:

* Standard format: ~15 minutes
* Logical-only format: ~3 seconds

This difference had a significant impact on usability.

---

## From Prototype to Public Tool

Initially, the tool was not released publicly.

Given that it directly modified disk structures, releasing it in a prototype state felt risky.

However, a colleague requested to try it and gave very positive feedback.

Based on that response, development continued toward a more stable and publicly usable tool.

---

## Extension to 230MB Media

The original version targeted 120MB MO drives.

Soon after, 230MB-capable drives became available, and were adopted immediately.

Support for 230MB media was added to MOFORMAT without difficulty.

---

## Multi-Format Support

Around the same time, discussions on BBS systems mentioned that:

> If an MO disk is formatted in IBM format, it can be used directly with PC/AT systems.

Based on this, support for additional formats was added:

* Human68k format
* IBM format
* Semi-IBM format

---

## Compatibility

At the time, several user-made MO formatters already existed.

However, media formatted by those tools were often not compatible with\
disks formatted by the standard OS formatter.

This caused practical issues such as:

* Disk-to-disk copy failing between MO media of the same capacity
* Inconsistent behavior depending on which formatter was used

MOFORMAT takes a different approach.

By copying the management area from media formatted by the standard formatter,\
it reproduces the exact layout used by official tools.

As a result:

* Media formatted by MOFORMAT is compatible with standard OS-formatted media
* Disk copying between devices works reliably,\
regardless of whether the media was formatted by MOFORMAT or the standard OS formatter.

The same approach was applied to IBM and Semi-IBM formats,\
using data derived from what were considered standard formatters at the time.

---

## Summary

MOFORMAT was not created from formal specifications.

Instead, it was developed from:

* practical observation
* reverse-engineered data
* real usage requirements

Its primary goal was simple:

> Reduce waiting time and improve usability.

As a result, it became a formatter that is both efficient and practical for everyday use.
