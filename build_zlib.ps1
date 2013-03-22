#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-21 23:19:02 -0600
#
# TODO:
#   - extract generics into a downloadable utils helper module
#   - add x86/x64 dynamic package naming

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='zlib version to build (eg - 1.2.7)')]
  [alias('v')]
  [validateset('1.2.7')]
  [string] $version,

  [parameter(HelpMessage='Path to 7-Zip command line tool')]
  [string] $7ZA = 'C:/tools/7za.exe',

  [parameter(HelpMessage='Path to DevKit root directory')]
  [string] $DEVKIT = 'C:/Devkit'
)

$libname = 'zlib'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = 'http://zlib.net/'
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.md5"

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

  # build
  Write-Status "building ${source_dir}"
  sh -c "make -f win32/Makefile.gcc" | Out-Null

  # install
  $install_opts = @("BINARY_PATH=${install_dir}/bin",
                    "INCLUDE_PATH=${install_dir}/include",
                    "LIBRARY_PATH=${install_dir}/lib",
                    "SHARED_MODE=1")
  sh -c "make install -f win32/Makefile.gcc $(${install_opts} -join ' ')" | Out-Null

  # archive
  Archive-Build

Pop-Location

# hoist binary archive and cleanup
Clean-Build
