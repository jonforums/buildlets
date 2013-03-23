#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-22 22:51:21 -0600
#
# TODO:
#   - extract generics into a downloadable utils helper module
#   - add x86/x64 dynamic package naming

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='OpenSSL version to build (eg - 1.0.1e).')]
  [validateset('1.0.0k','1.0.1e')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='mingw toolchain flavor to use (eg - mingw, mingw64)')]
  [validateset('mingw','mingw64')]
  [string] $toolchain = 'mingw',

  [parameter(HelpMessage='Path to DevKit root directory')]
  [string] $DEVKIT = 'C:/Devkit',

  [parameter(HelpMessage='Path to zlib dev libraries root directory')]
  [alias('with-zlib-dir')]
  [string] $ZLIBDIR = 'C:/devlibs/zlib-1.2.7'
)

$libname = 'openssl'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = 'http://www.openssl.org/source/'
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.sha1"

# download and source the buildlet library
if (-not (Test-Path "$PWD\buildlet_utils.ps1")) {
  Write-Host '---> fetching buildlet library' -foregroundcolor yellow
  try {
    $fetcher = New-Object System.Net.WebClient
    $fetcher.DownloadFile('https://raw.github.com/jonforums/buildlets/master/buildlet_utils.ps1',
                          "$PWD\buildlet_utils.ps1")
  }
  catch {
    throw '[ERROR] unable to fetch required buildlet library'
  }
}
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
  Write-Status "patching ${source_dir}"
  Push-Location test
    rm md2test.c,rc5test.c,jpaketest.c
  Pop-Location

  # activate toolchain
  Activate-Toolchain
  $env:CPATH = "$ZLIBDIR/include"

  # configure
  Write-Status "configuring ${source_dir}"
  $install_dir = "$($PWD.ToString().Replace('\','/'))/my_install"
  perl Configure $toolchain zlib-dynamic shared --prefix="$install_dir" | Out-Null

  # build
  Write-Status "building ${source_dir}"
  sh -c "make" | Out-Null

  # install
  sh -c "make install_sw" | Out-Null

  # archive
  Archive-Build

Pop-Location

# hoist binary archive and cleanup
Clean-Build
