#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-22 21:44:38 -0600

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
$buildlets = @('build_libffi'
               'build_lua'
               'build_minised'
               'build_openssl'
               'build_zlib'
              )
$buildlet_uri = 'https://raw.github.com/jonforums/buildlets/master/'

# download build tools
if (-not (Test-Path "$tools_root" -type container)) {
  Write-Host "---> creating $tools_root" -foregroundcolor yellow
  New-Item $tools_root -type directory -force | Out-Null
}

$fetcher = New-Object System.Net.WebClient
$tools | % {
  if (-not (Test-Path (Join-Path "$tools_root" "$_") -type leaf)) {
    Write-Host "---> downloading tool: $_" -foregroundcolor yellow
    $fetcher.DownloadFile("${tools_uri}$_", $(Join-Path "$tools_root" "$_"))
  }
}

# download specified buildlet if given
if (($buildlet) -and ($buildlets -contains $buildlet) -and `
    (-not (Test-Path "${buildlet}.ps1" -type leaf))) {
  Write-Host "---> downloading ${buildlet}.ps1" -foregroundcolor yellow
  $fetcher.DownloadFile("${buildlet_uri}${buildlet}.ps1", $(Join-Path "$PWD" "${buildlet}.ps1"))
}
