#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-20 20:37:57 -0600
#
# TODO:
#   - extract generics into a downloadable utils helper module
#   - add proper try-catch-finally error handling
#   - add x86/x64 dynamic package naming

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='lua version to build (eg - 5.2.1)')]
  [validateset('5.2.1')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='Path to 7-Zip command line tool')]
  [string] $7ZA = 'C:/tools/7za.exe',

  [parameter(HelpMessage='Path to DevKit root directory')]
  [string] $DEVKIT = 'C:/Devkit'
)

$root = Split-Path -parent $script:MyInvocation.MyCommand.Path
$libname = 'lua'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://www.lua.org/ftp/"
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.sha1"

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
  #Write-Host "[ERROR] $source validation failed, exiting" -foregroundcolor red
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
  $maj_min = ($version -split '\.')[0..1] -join ''
  $to_bin = 'lua.exe','luac.exe',"lua${maj_min}.dll"
  $to_inc = 'lua.h','luaconf.h','lualib.h','lauxlib.h','lua.hpp'
  $to_lib = 'liblua.a'

  # build
  Write-Status "building ${source_dir}"
  Push-Location src
    sh -c "make mingw" | Out-Null
  Pop-Location

  # install
  Push-Location src
    New-Item "$install_dir/bin","$install_dir/include","$install_dir/lib" -itemtype directory | Out-Null
    mv $to_bin "$install_dir/bin"
    mv $to_inc "$install_dir/include"
    mv $to_lib "$install_dir/lib"
    mv (Resolve-Path ../doc) "$install_dir"
  Pop-Location

  # archive
  Push-Location "$install_dir"
    Write-Status "creating binary archive for ${source_dir}"
    $bin_archive = "${source_dir}-x86-windows-bin.7z"
    & "$7ZA" "a" "-mx=9" "-r" $bin_archive "*" | Out-Null
  Pop-Location

Pop-Location

# hoist binary archive and cleanup
Write-Status "cleaning up"
mv "$install_dir/$bin_archive" "$PWD"
rm -recurse -force "${source_dir}"
