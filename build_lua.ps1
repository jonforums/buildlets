#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-22 22:54:15 -0600
#
# TODO:
#   - extract generics into a downloadable utils helper module
#   - add x86/x64 dynamic package naming

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='lua version to build (eg - 5.2.1)')]
  [validateset('5.2.1')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='Path to DevKit root directory')]
  [string] $DEVKIT = 'C:/Devkit'
)

$libname = 'lua'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://www.lua.org/ftp/"
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

  # activate toolchain
  Activate-Toolchain

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
  Archive-Build

Pop-Location

# hoist binary archive and cleanup
Clean-Build
