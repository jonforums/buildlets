#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-11-10 14:15:09 -0600

param (
    [parameter(Mandatory=$false,
               Position=0,
               HelpMessage='Buildlet to download')]
    [alias('b')]
    [string] $buildlet = $nil
)

$tools = @('7za.exe')
$tools_root = "$PWD\tools"
$tools_uri = 'https://raw.github.com/jonforums/buildlets/master/tools/'

# TODO not DRY enough
$buildlets = @('build_bzip2'
               'build_libffi'
               'build_libiconv'
               'build_liblzma'
               'build_lua'
               'build_minised'
               'build_openssl'
               'build_tcltk'
               'build_unqlite'
               'build_zlib'
              )
$buildlet_uri = 'https://raw.github.com/jonforums/buildlets/master/'

switch -regex ($buildlet) {
  '^(?:ls|list)$' {
    Write-Host "`n== Available Buildlets ==" -foregroundcolor green
    $buildlets | % { Write-Host "   $_" -foregroundcolor yellow }
    return
  }
}

Write-Debug '---> downloading buildlet library and tools'
# download buildlet utility library and required tools
$fetcher = New-Object System.Net.WebClient

if (-not (Test-Path "$PWD\buildlet_utils.ps1")) {
  Write-Host '---> fetching buildlet library' -foregroundcolor yellow
  try {
    $fetcher.DownloadFile('https://raw.github.com/jonforums/buildlets/master/buildlet_utils.ps1',
                          "$PWD\buildlet_utils.ps1")
  }
  catch {
    throw '[ERROR] unable to fetch required buildlet library'
  }
}

if (-not (Test-Path "$tools_root" -type container)) {
  Write-Host "---> creating $tools_root" -foregroundcolor yellow
  New-Item $tools_root -type directory -force | Out-Null
}

$tools | % {
  if (-not (Test-Path (Join-Path "$tools_root" "$_") -type leaf)) {
    Write-Host "---> downloading tool: $_" -foregroundcolor yellow
    try {
      $fetcher.DownloadFile("${tools_uri}$_", $(Join-Path "$tools_root" "$_"))
    }
    catch {
      throw "[ERROR] unable to fetch required build tool $_"
    }
  }
}

Write-Debug "---> downloading $buildlet"
# download specified buildlet if given
if (($buildlet) -and ($buildlets -contains $buildlet) -and `
    (-not (Test-Path "${buildlet}.ps1" -type leaf))) {
  Write-Host "---> downloading ${buildlet}.ps1" -foregroundcolor yellow
  try {
    $fetcher.DownloadFile("${buildlet_uri}${buildlet}.ps1", $(Join-Path "$PWD" "${buildlet}.ps1"))
  }
  catch {
    throw "[ERROR] unable to fetch ${buildlet} buildlet"
  }
}
