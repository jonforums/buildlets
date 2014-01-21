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

* PowerShell 3.0+
* .NET Framework v3.5+
* Live internet connection
* MinGW or mingw-w64 based toolchain with MSYS, Autotools, and Perl superpowers.
  Currently, buildlets requires that you create a `toolchain.json` file describing
  the relevant `PATH` to your 32-bit and 64-bit msys/mingw-based toolchains.

## Basic Usage

Assuming you have a capable mingw or mingw-w64 toolchain already installed, typical
usage can be as simple as the following:

1. Open PowerShell
2. Download the `bootstrap.ps1` script

        curl
        ====
          curl --cacert C:\tools\cacert.pem -L -O https://raw.github.com/jonforums/buildlets/master/bootstrap.ps1

        powershell via cmd.exe
        ======================
          @powershell -NoProfile -ExecutionPolicy unrestricted -Command "(new-object net.webclient).DownloadFile('https://raw.github.com/jonforums/buildlets/master/bootstrap.ps1', 'bootstrap.ps1')"

3. Create a `toolchain.json` file describing the `PATH` requirements of your build toolchains

        {
          "x32": {
            "path": [
              "C:/DevKit-x32-4.8.2/bin",
              "C:/DevKit-x32-4.8.2/mingw/bin"
            ],
            "build": "i686-w64-mingw32"
          },

          "x64": {
            "path": [
              "C:/Apps/DevTools/msys/bin",
              "C:/Apps/DevTools/mingw/bin"
            ],
            "build": "x86_64-w64-mingw32"
          }
        }

4. Execute `bootstrap.ps1` to list available buildlets, automatically fetch any
   required build tool, and optionally, download an initial buildlet

        PS foo> .\bootstrap.ps1 ls

        == Available Buildlets ==
           build_bzip2
           build_libarchive
           build_libffi
           build_libiconv
           build_liblzma
           build_lua
           build_lzo2
           build_minised
           build_openssl
           build_sqlite
           build_tcltk
           build_unqlite
           build_zlib

        PS foo> .\bootstrap.ps1 build_lua
        ---> creating C:\Users\Jon\Downloads\temp\foo\tools
        ---> downloading tool: 7za.exe
        ---> downloading build_lua.ps1

5. Execute the buildlet

        PS foo> .\build_lua.ps1 5.2.1
        ---> fetching buildlet library
        ---> downloading http://www.lua.org/ftp/lua-5.2.1.tar.gz
        ---> validating lua-5.2.1.tar.gz
        ---> extracting lua-5.2.1.tar.gz
        ---> activating toolchain
        ---> configuring lua-5.2.1
        ---> building lua-5.2.1
        ---> creating binary archive for lua-5.2.1
        ---> cleaning up

        PS foo> .\build_lua.ps1 5.2.2 -x64
        ---> downloading http://www.lua.org/ftp/lua-5.2.2.tar.gz
        ---> validating lua-5.2.2.tar.gz
        ---> extracting lua-5.2.2.tar.gz
        ---> activating toolchain [64-bit]
        ---> configuring lua-5.2.2 [64-bit]
        ---> building lua-5.2.2 [64-bit]
        ---> creating binary archive for lua-5.2.2 [64-bit]
        ---> cleaning up

6. Find built artifacts in the `pkg` sub-directory

## License

3-clause BSD
