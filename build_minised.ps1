#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-11-07 17:10:29 -0600
#
# TODO:
#   - extract generics into a downloadable utils helper module

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='minised version to build (eg - 1.14)')]
  [validateset('1.14')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'minised'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://dl.exactcode.de/oss/${libname}/"
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
  Configure-Build {
    mkdir "$install_dir" | Out-Null
  }

  # build
  New-Build {
    sh -c "make CC=gcc" | Out-Null
  }

  # install
  strip -s minised.exe | Out-Null
  cp minised.exe, README, LICENSE -destination "$install_dir" | Out-Null

  # archive
  Archive-Build

  # hoist binary archive to top level
  Move-ArchiveToRoot

Pop-Location

# cleanup
Clean-Build
