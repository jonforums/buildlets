#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-09-26 14:47:47 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='OpenSSL version to build (eg - 1.1.1h).')]
  [validateset('1.1.1h')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='Perform a 64-bit build')]
  [switch] $x64,

  [parameter(HelpMessage='Create a static CLI exe')]
  [switch] $cli,

  [parameter(HelpMessage='Path to zlib dev libraries root directory')]
  [alias('with-zlib-dir')]
  [string] $ZLIB_DIR = 'C:/devlibs/zlib/x86/1.2.11'
)

$libname = 'openssl'
$source = "${libname}-${version}.tar.gz"
$build_name = "${libname}-${version}"
$repo_root = 'https://www.openssl.org/source/'
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
Push-Location "${build_src_dir}"

  # activate toolchain
  Activate-Toolchain {
    $ZLIB_DIR = $ZLIB_DIR.Replace('\', '/')

    $env:CPATH = "$ZLIB_DIR/include"
    # FIXME more cleanly integrate with existing Configure script invocation
    $env:CC = 'gcc -static-libgcc'
  }

  # configure
  Configure-Build {
    if ($cli) {
      $env:CFLAGS = "-static"
      # use zlib and no-shared for self-contained binary
      perl Configure $mingw_flavor zlib no-shared --prefix="$install_dir" --openssldir='C:/tools/ssl' | Out-Null
    } else {
      perl Configure $mingw_flavor zlib-dynamic shared --prefix="$install_dir" | Out-Null
    }
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
