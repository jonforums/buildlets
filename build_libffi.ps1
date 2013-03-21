#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-21 12:22:36 -0600
#
# TODO:
#   - extract generics into a downloadable utils helper module
#   - add proper try-catch-finally error handling
#   - add x86/x64 dynamic package naming

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='libffi version to build (eg - 3.0.12)')]
  [alias('i')]
  [validateset('3.0.10','3.0.11','3.0.12')]
  [string] $version,

  [parameter(HelpMessage='Path to 7-Zip command line tool')]
  [string] $7ZA = 'C:/tools/7za.exe',

  [parameter(HelpMessage='Path to DevKit root directory')]
  [string] $DEVKIT = 'C:/Devkit'
)

$root = split-path -parent $script:MyInvocation.MyCommand.Path
$libname = 'libffi'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "ftp://sourceware.org/pub/${libname}/"
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.md5"

function Write-Status($msg, $leader='--->', $color='Yellow') {
  Write-Host "$leader $msg" -foregroundcolor $color
}

# download and verify
# TODO implement progress bar when extracted to util helper module
if(-not (Test-Path $source)) {

  try {
    Write-Status "downloading $archive"
    [System.Net.FtpWebRequest]$request = [System.Net.WebRequest]::Create($archive)
    $request.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $request.UseBinary = $true
    $request.UsePassive = $true

    $response = $request.GetResponse()
    $response_stream = $response.GetResponseStream()
    $fs = New-Object System.IO.FileStream "$PWD/$source", 'Create', 'Write'

    [byte[]] $buffer = New-Object byte[] 4096

    do {
      $count = $response_stream.Read($buffer, 0, $buffer.Length)
      $fs.Write($buffer, 0, $count)
    } while ($count -gt 0)  # EOS when Read returns 0 bytes
  }
  catch {
    throw "[ERROR] Oops trying to download"
  }
  finally {
    if ($fs) { $fs.Flush(); $fs.Close() }
    if ($response_stream) { $response_stream.Close() }
    if ($response) { $response.Close() }
  }
}

# download hash data and validate source archive
Write-Status "validating $source"
$client = New-Object System.Net.WebClient
$hash = ConvertFrom-StringData $client.DownloadString($hash_uri)

try {
  $hasher = New-Object System.Security.Cryptography.MD5Cng
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
  sh -c "./configure --prefix=${install_dir}" | Out-Null

  # build
  Write-Status "building ${source_dir}"
  sh -c "make" | Out-Null

  # install
  sh -c "make install" | Out-Null

  # post-install patch
  Push-Location "$install_dir"
    mv $(Resolve-Path lib\libffi-*\include) $PWD
    rm $(Resolve-Path lib\libffi-*)
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
mv "$install_dir/$bin_archive" "$PWD" -force
rm "${source_dir}" -recurse -force
