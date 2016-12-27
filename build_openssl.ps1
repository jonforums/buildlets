#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2016-12-27 09:28:10 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='OpenSSL version to build (eg - 1.1.0c).')]
  [validateset('1.0.1u','1.0.2j','1.1.0c')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64,

  [parameter(HelpMessage='Path to zlib dev libraries root directory')]
  [alias('with-zlib-dir')]
  [string] $ZLIB_DIR = 'C:/devlibs/zlib/x86/1.2.8'
)

$libname = 'openssl'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = 'http://www.openssl.org/source/'
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.sha1"

if ($x64) { $mingw_flavor = 'mingw64' } else { $mingw_flavor = 'mingw' }

# source the buildlet library
. "$PWD\buildlet_utils.ps1"

# download source archive
Fetch-Archive

# download hash data and validate source archive
Validate-Archive

# extract
Extract-Archive

# patch, configure, build, archive
Push-Location "${source_dir}"

  # patch
  #Write-Status "patching ${source_dir}"
  #Push-Location test
  #rm md2test.c,rc5test.c,jpaketest.c
  #Pop-Location

  # activate toolchain
  Activate-Toolchain {
    $env:CPATH = "$ZLIB_DIR/include"
    # FIXME more cleanly integrate with existing Configure script invocation
    $env:CC = 'gcc -static-libgcc'
  }

  # configure
  Configure-Build {
    perl Configure $mingw_flavor zlib-dynamic no-shared --prefix="$install_dir" | Out-Null
  }

  # build
  New-Build {
    sh -c "make" | Out-Null
  }

  # install
  sh -c "make install_sw" | Out-Null

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
