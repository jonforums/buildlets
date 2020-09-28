#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-09-27 19:24:20 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='Zstd version to build (eg - 1.4.5)')]
  [validateset('1.4.5')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64,

  [parameter(HelpMessage='path to zlib dev libraries root directory')]
  [alias('with-zlib-dir')]
  [string] $ZLIB_DIR = 'C:/devlibs/zlib/x86/1.2.11',

  [parameter(HelpMessage='path to lzma dev libraries root directory')]
  [alias('with-lzma-dir')]
  [string] $LZMA_DIR = 'C:/devlibs/lzma/x86/5.2.5'
)

$libname = 'zstd'
$source = "${libname}-${version}.tar.gz"
$build_name = "${libname}-${version}"
$repo_root = "https://github.com/facebook/${libname}/releases/download/v${version}/"
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.sha1"

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
    $LZMA_DIR = $LZMA_DIR.Replace('\', '/')
    
    $env:CPPFLAGS = "-I $ZLIB_DIR/include -I $LZMA_DIR/include"
    $env:LDFLAGS = "-L $LZMA_DIR/lib -L $ZLIB_DIR/lib -l:liblzma.a -l:libz.a"
  }

  # configure
  Configure-Build

  # build
  New-Build {
    sh -c "make zstd HAVE_THREAD=1 ZSTD_LEGACY_SUPPORT=0 HAVE_ZLIB=1 HAVE_LZMA=1" | Out-Null
  }

  # stage
  Stage-Build {
    New-Item "$install_dir" -itemtype directory | Out-Null
    mv "${libname}.exe" "$install_dir" | Out-Null
    strip --strip-unneeded "$install_dir/${libname}.exe" | Out-Null
  }

  # archive
  Archive-Build -variant 'static-cli'

Pop-Location

# cleanup
Clean-Build
