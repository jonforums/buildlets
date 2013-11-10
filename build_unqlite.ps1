#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-11-10 15:10:29 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='unqlite version to build (eg - 20130825-116).')]
  [validateset('20130825-116')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'unqlite'
$source = "${libname}-db-${version}.zip"
$source_dir = "${libname}-${version}"
$repo_root = 'http://unqlite.org/db/'
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.sha1"

# source the buildlet library
. "$PWD\buildlet_utils.ps1"

# download source archive
Fetch-Archive

# download hash data and validate source archive
Validate-Archive

# extract
Extract-CustomArchive

# patch, configure, build, archive
Push-Location "${source_dir}"

  # activate toolchain
  Activate-Toolchain

  # configure
  Configure-Build {
    $defines = '-D_WIN32_WINNT=0x0501'
    $script:cflags = "-g $defines -Wall -Wextra -O2"
  }

  # build
  New-Build {
    sh -c "gcc $cflags -c ${libname}.c -o ${libname}.o" | Out-Null
    sh -c "gcc -shared -Wl,--output-def,${libname}.def -Wl,--out-implib,lib${libname}.dll.a -o ${libname}.dll ${libname}.o"
    sh -c "ar rcs lib${libname}.a ${libname}.o" | Out-Null
  }

  # stage
  Stage-Build {
    New-Item "$install_dir/bin","$install_dir/include", "$install_dir/lib" `
             -itemtype directory | Out-Null
    cp "${libname}.dll" "$install_dir/bin" | Out-Null
    cp "${libname}.h" "$install_dir/include" | Out-Null
    cp "lib${libname}.a", "lib${libname}.dll.a" "$install_dir/lib" | Out-Null
    cp "${libname}.def" "$install_dir/lib" | Out-Null
  }

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
