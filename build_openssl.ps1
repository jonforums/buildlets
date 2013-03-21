#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-20 23:06:25 -0600
#
# TODO:
#   - extract generics into a downloadable utils helper module
#   - add try-catch-finally error handling
#   - add x86/x64 dynamic package naming

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='OpenSSL version to build (eg - 1.0.1e).')]
  [alias('v')]
  [validateset('1.0.0k','1.0.1e')]
  [string] $version,

  [parameter(HelpMessage='mingw toolchain flavor to use (eg - mingw, mingw64)')]
  [validateset('mingw','mingw64')]
  [string] $toolchain = 'mingw',

  [parameter(HelpMessage='Path to 7-Zip command line tool')]
  [string] $7ZA = 'C:/tools/7za.exe',

  [parameter(HelpMessage='Path to DevKit root directory')]
  [string] $DEVKIT = 'C:/Devkit',

  [parameter(HelpMessage='Path to zlib dev libraries root directory')]
  [alias('with-zlib-dir')]
  [string] $ZLIBDIR = 'C:/devlibs/zlib-1.2.7'
)

$root = Split-Path -parent $script:MyInvocation.MyCommand.Path
$libname = 'openssl'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = 'http://www.openssl.org/source/'
$archive = "${repo_root}${source}"
$archive_hash = "${repo_root}${source}.sha1"

function Write-Status($msg, $leader='--->', $color='Yellow') {
  Write-Host "$leader $msg" -foregroundcolor $color
}

# download source archive
if(-not (Test-Path $source)) {
  Import-Module BitsTransfer
  Write-Status "downloading $archive"
  Start-BitsTransfer $archive "$PWD\$source"
}

# download hash data and validate source archive
Write-Status "validating $source"
$client = New-Object System.Net.WebClient
$hash = $client.DownloadString($archive_hash).Trim(" ","`r","`n").ToLower()

try {
  $hasher = New-Object System.Security.Cryptography.SHA1Cng
  $fs = New-Object System.IO.FileStream "$PWD\$source", 'Open', 'Read'
  $test_hash = [BitConverter]::ToString($hasher.ComputeHash($fs)).Replace('-','').ToLower()
} finally {
  $fs.Close()
}

if ($test_hash -ne $hash) {
  Write-Status "$source validation failed, exiting" '[ERROR]' 'Red'
  break
}


# extract
Write-Status "extracting $source"
$tar_file = $source.Substring(0, $source.LastIndexOf('.'))
(& "$7ZA" "x" $source) -and (& "$7ZA" "x" $tar_file) -and (rm $tar_file) | Out-Null


# patch, configure, build, archive
Push-Location "${source_dir}"

  # patch
  Write-Status "patching ${source_dir}"
  Push-Location test
    rm md2test.c,rc5test.c,jpaketest.c
  Pop-Location

  # activate toolchain
  Write-Status "activating toolchain"
  . "$DEVKIT/devkitvars.ps1" | Out-Null
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
  Push-Location "$install_dir"
    Write-Status "creating binary archive for ${source_dir}"
    $bin_archive = "${source_dir}-x86-windows-bin.7z"
    & "$7ZA" "a" "-mx=9" "-r" $bin_archive "*" | Out-Null
  Pop-Location

Pop-Location

# hoist binary archive and cleanup
Write-Status "cleaning up"
mv "$install_dir/$bin_archive" "$PWD" -force
rm "${source_dir}" -recurse -force
