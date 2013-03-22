## Buildlets

An eclectic collection of single file, minimal dependency, PowerShell-based
build recipes for creating libraries and executables on mingw/minw-w64
Windows systems.

In contrast with other well known port-style systems, buildlets enable one to
quickly build binary artifacts with minimal ceremony and minimal persistent
configuration. Typically one downloads a buildlet, runs it, and gets a binary
archive. What you do next is up to you.

Buildlets are very mercenary in their focus and actions. No interdependency
management. No complex configuration nor massive directory trees of persistent
local data. As such, the buildlet system will always be a tradeoff between
minimalism and modular reusability.

## Dependencies

* PowerShell 2.0+
* Live internet connection
* MinGW or mingw-w64 based toolchain with MSYS, Autotools, and Perl superpowers
* 7za.exe command line file archiving tool

## Usage

## TODO

* `get_build_deps.ps1` build dependency downloader
* download source to `downloads` and place binary archives in `pkg`
* use build customizations from `buildlets.conf` if present

## License

3-clause BSD
