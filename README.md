# MOFORMAT

MO disk formatter for X68000, preserved as original implementation.

---

## Overview

MOFORMAT is a formatter for Magneto-Optical (MO) disks on X68000.

It was designed with compatibility as the highest priority,\
matching the behavior of existing formatters used at the time.

Supported formats include:

* Human68k format
* IBM format
* Semi-IBM format

---

## Design Philosophy

MOFORMAT was not designed based on official specifications.

Instead, it was developed by observing the actual output of existing formatters\
and reproducing their behavior to achieve compatibility.

This approach ensured that formatted media would behave identically\
to those created by standard tools.

---

## Source Code Policy

This repository preserves the original implementation as much as possible.

However, some parts of the original source code are not included.

These omitted parts depend on data derived from existing formatters,\
and are excluded to avoid redistributing third-party binary data.

---

## Included Source Files

* `moformat.s`
  Main logic of the formatter.

---

## Referenced but Not Included

The following files are referenced by the original source code,\
but are not included in this repository:

* `clripl.s`
  Utility code/data related to clearing existing IPL area.\
  Not included because it depends on non-original formatter-derived data.

* `data_block00.s`
  Data block written to sector range $00–1F of Human68k-formatted media.\
  Not included because it contains data derived from existing formatter output.

* `data_block40.s`
  Data block written to sector range $40–41 of Human68k-formatted media.\
  Not included because it contains data derived from existing formatter output.

* `ibm_ipl.s`
  IBM-format IPL / boot sector related data.\
  Not included because it is based on formatter-derived binary data.

* `moipll.s`
  Utility used when extracting or handling MO IPL related data.\
  Not included together with formatter-derived components.

* `sibm_ipl.s`
  Semi-IBM format IPL related data.\
  Not included because it is based on formatter-derived binary data.

---

## Executable

The original executable is included in this repository.

It is provided as-is for historical preservation.

The executable may contain data derived from existing formatter outputs,\
and is included for reference purposes only.

---

## Notes

* This repository does not provide a complete buildable environment.
* Some required data blocks and IPL components are intentionally omitted.
* The purpose of this repository is to preserve the original design,\
  structure, and implementation approach.

---

## Status

This repository preserves the original implementation.

The source code and documentation are provided as-is,\
with minimal modification.

---

## License

MIT License
