#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-20 21:17:27 -0600
#
# TODO:
#   - extract generics into a downloadable utils helper module
#   - add proper try-catch-finally error handling
#   - add x86/x64 dynamic package naming

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='minised version to build (eg - 1.14)')]
  [validateset('1.14')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='Path to 7-Zip command line tool')]
  [string] $7ZA = 'C:/tools/7za.exe',

  [parameter(HelpMessage='Path to DevKit root directory')]
  [string] $DEVKIT = 'C:/Devkit'
)

$root = Split-Path -parent $script:MyInvocation.MyCommand.Path
$libname = 'minised'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://dl.exactcode.de/oss/${libname}/"
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/poshlab/master/hashery/${libname}.sha1"

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
$hash = ConvertFrom-StringData $client.DownloadString($hash_uri)

try {
  $hasher = New-Object System.Security.Cryptography.SHA1Cng
  $fs = New-Object System.IO.FileStream "$PWD\$source", 'Open', 'Read'
  $test_hash = [BitConverter]::ToString($hasher.ComputeHash($fs)).Replace('-','').ToLower()
} finally {
  $fs.Close()
}

if ($test_hash -ne $hash[$version].ToLower()) {
  Write-Status "$source validation failed, exiting" '[ERROR]' 'Red'
  break
}


# extract
Write-Status "extracting $source"
$tar_file = "$($source.Substring(0, $source.LastIndexOf('-')))*.tar"
(& "$7ZA" "x" $source) -and (& "$7ZA" "x" $tar_file) -and (rm $tar_file) | Out-Null


# patch, configure, build, archive
Push-Location "${source_dir}"

  # activate toolchain
  Write-Status "activating toolchain"
  . "$DEVKIT/devkitvars.ps1" | Out-Null

  # configure
  Write-Status "configuring ${source_dir}"
  $install_dir = "$($PWD.ToString().Replace('\','/'))/my_install"
  mkdir "$install_dir" | Out-Null

  # build
  Write-Status "building ${source_dir}"
  sh -c "make CC=gcc" | Out-Null

  # install
  strip -s minised.exe | Out-Null
  cp minised.exe, README, LICENSE -destination "$install_dir" | Out-Null

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
