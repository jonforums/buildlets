#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2014-01-21 10:57:52 -0600

# TODO - remove libgcc_s_sjlj-1.dll dependency from libarchive-13.dll
#      - why doesn't x64 build libarchive-13.dll; says bad libbz2.a and liblzma (!?)

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='libarchive version to build (eg - 3.1.2)')]
  [validateset('3.1.2')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64,

  [parameter(HelpMessage='Path to zlib dev libraries root directory')]
  [alias('with-zlib-dir')]
  [string] $ZLIB_DIR = 'C:/devlibs/zlib/x86/1.2.8',

  [parameter(HelpMessage='Path to liblzma dev libraries root directory')]
  [alias('with-lzma-dir')]
  [string] $LZMA_DIR = 'C:/devlibs/liblzma/x86/5.0.5',

  [parameter(HelpMessage='Path to libbz2 dev libraries root directory')]
  [alias('with-bzip2-dir')]
  [string] $BZIP2_DIR = 'C:/devlibs/libbz2/x86/1.0.6',

  [parameter(HelpMessage='Path to libiconv dev libraries root directory')]
  [alias('with-iconv-dir')]
  [string] $ICONV_DIR = 'C:/devlibs/libiconv/x86/1.14'
)

$libname = 'libarchive'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://libarchive.org/downloads/"
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
Push-Location "${source_dir}"

  # activate toolchain
  Activate-Toolchain {
    $env:CPATH = "$ZLIB_DIR/include;$LZMA_DIR/include;$BZIP2_DIR/include"
    $env:LIBRARY_PATH = "$ZLIB_DIR/lib;$LZMA_DIR/lib;$BZIP2_DIR/lib"
  }

  # configure
  Configure-Build {
    $cfg_args = @('--enable-bsdtar=static'
                  '--enable-bsdcpio=static'
                  '--disable-rpath'
                  '--disable-posix-regex-lib'
                  '--disable-xattr'
                  '--disable-acl'
                  '--without-lzmadec'
                  '--without-lzo2'
                  '--without-iconv'
                  '--without-nettle'
                  '--without-openssl'
                  '--without-xml2'
                  '--without-expat'
                  "--prefix=${install_dir}")

    sh -c "./configure $($cfg_args -join ' ') ${triplets}" | Out-Null
  }

  # build
  New-Build {
    sh -c "make" | Out-Null
  }

  # install
  sh -c "make install" | Out-Null

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
