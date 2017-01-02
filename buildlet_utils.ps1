#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2017-01-01 20:56:14 -0600

# save the clean path
$script:original_path = $env:PATH

# always build using a pristine PATH free of lurking customization monsters
$env:PATH = 'C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\'

# buildlet execution root directory
$buildlet_root = Split-Path -parent $MyInvocation.MyCommand.Path

trap {
  Clean-Build
}

# parse and validate user specified toolchain configuration data
function private:Validate-Toolchain() {
  if (-not ($toolchain.x86)) {
    throw '[ERROR] must provide a 32-bit toolchain configuration'
  }
  if (-not ($toolchain.x86.path)) {
    throw '[ERROR] must provide PATH information for the 32-bit toolchain'
  }
  if ($toolchain.x86.path -isnot [System.Array]) {
    throw '[ERROR] 32-bit toolchain PATH info must be in an array'
  }
  if (-not ($toolchain.x86.path.count -gt 0)) {
    throw '[ERROR] 32-bit toolchain PATH array must contain paths'
  }
  if (-not ($toolchain.x86.build)) {
    throw '[ERROR] must provide build triplet for the 32-bit toolchain'
  }
  if ($toolchain.x64) {
    if (-not ($toolchain.x64.path)) {
      throw '[ERROR] must provide PATH information for the 64-bit toolchain'
    }
    if ($toolchain.x64.path -isnot [System.Array]) {
      throw '[ERROR] 64-bit toolchain PATH info must be in an array'
    }
    if (-not ($toolchain.x64.path.count -gt 0)) {
      throw '[ERROR] 32-bit toolchain PATH array must contain paths'
    }
    if (-not ($toolchain.x64.build)) {
      throw '[ERROR] must provide build triplet for the 64-bit toolchain'
    }
  }
}

try {
  if (Test-Path 'toolchain.json') {
    $toolchain = Get-Content 'toolchain.json' | Out-String | ConvertFrom-Json
    Validate-Toolchain
  }
  else {
    throw '[ERROR] must provide `toolchain.json` config file'
  }
}
catch {
  throw
}

# by default, ensure internal build tools are used
if (-not "$s7z") {
  $s7z = "$PWD\tools\7za.exe"
}

# TODO implement `.\buildlet.conf` customization capability using
# `ConvertFrom-StringData` converts `name = value` pairs into hash tables

function Write-Status($msg, $leader='--->', $color='Yellow') {
  Write-Host "$leader $msg" -foregroundcolor $color
}

function Fetch-Archive() {
  if (-not (Test-Path $source)) {
    Write-Status "downloading $archive"
    $uri = New-Object System.URI $archive

    switch -regex ($uri.Scheme.ToLower()) {
      '^(?:http|https)' {
        Import-Module BitsTransfer
        Start-BitsTransfer $archive "$PWD\$source"
        break
      }
      '^ftp$' {
        try {
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
          throw "[ERROR] failure trying to perform FTP download"
        }
        finally {
          if ($fs) { $fs.Flush(); $fs.Close() }
          if ($response_stream) { $response_stream.Close() }
          if ($response) { $response.Close() }
        }
        break
      }
      default { throw "[ERROR] unsupported network scheme: $($uri.Scheme.ToLower())" }
    }
  }
}

function Validate-Archive() {
  try {
    Write-Status "validating $source"
    $fetcher = New-Object System.Net.WebClient
    $hash = ConvertFrom-StringData $fetcher.DownloadString($hash_uri)

    switch ($hash_uri.SubString($hash_uri.LastIndexOf('.')+1)) {
      'md5' { $hasher = New-Object System.Security.Cryptography.MD5Cng; break }
      'sha1' { $hasher = New-Object System.Security.Cryptography.SHA1Cng; break }
      'sha256' { $hasher = New-Object System.Security.Cryptography.SHA256Cng; break }
      'sha512' { $hasher = New-Object System.Security.Cryptography.SHA512Cng; break }
      default { throw }
    }

    $fs = New-Object System.IO.FileStream "$PWD\$source", 'Open', 'Read'
    $test_hash = [BitConverter]::ToString($hasher.ComputeHash($fs)).Replace('-','').ToLower()
  }
  catch {
    throw "[ERROR] unable to validate $source"
  }
  finally {
    $fs.Close()
  }

  if ($test_hash -ne $hash[$version].ToLower()) {
    throw "[ERROR] $source fingerprint different than expected value"
  }
}

function Extract-Archive() {
  Write-Status "extracting $source"
  $tar_file = "$($source.Substring(0, $source.LastIndexOf('-')))*.tar"
  (& "$s7z" "x" "-y" $source) -and (& "$s7z" "x" "-y" $tar_file) -and (rm $tar_file) | Out-Null
}

function Extract-CustomArchive {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  Write-Status "extracting $source"

  if ($block) {
    $block.Invoke()
  } else {
    (& "$s7z" "x" "-y" $source -o"${source_dir}") | Out-Null
  }
}

# TODO allow custom status message
function Activate-Toolchain() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  if ($x64) { $arch = '[64-bit]' }
  Write-Status "activating toolchain ${arch}"
  $new_path = $toolchain.x86.path -join ';'
  $script:triplets = "--build=$($toolchain.x86.build)"
  if ($x64) {
    if (-not $toolchain.x64) {
      throw '[ERROR] must provide 64-bit toolchain configuration'
    }
    $new_path = $toolchain.x64.path -join ';'
    $script:triplets = "--build=$($toolchain.x64.build)"
  }
  $env:PATH = "${new_path};${env:PATH}"

  if ($block) { $block.Invoke() }
}

# TODO alllow custom status message
function Apply-Patches() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  if ($x64) { $arch = '[64-bit]' }
  Write-Status "patching ${source_dir} ${arch}"

  if ($block) {
    $block.Invoke()
  } else {
    Get-ChildItem "${buildlet_root}/patches/${libname}" | Sort-Object | %{
      $patch = "${buildlet_root}/patches/${libname}/$_"
      Write-Status "   applying $_"
      patch -p1 -i "${patch}" | Out-Null
    }
  }
}

# TODO allow custom status message
function Configure-Build() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  if ($x64) { $arch = '[64-bit]' }
  Write-Status "configuring ${source_dir} ${arch}"
  $script:install_dir = "$($PWD.ToString().Replace('\','/'))/my_install"

  if ($block) { $block.Invoke() }
}

# TODO allow custom status message
function New-Build() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  if ($x64) { $arch = '[64-bit]' }
  Write-Status "building ${source_dir} ${arch}"

  if ($block) { $block.Invoke() }
}

# TODO allow custom status message
function Stage-Build() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  if ($x64) { $arch = '[64-bit]' }
  Write-Status "staging ${source_dir} ${arch}"

  if ($block) { $block.Invoke() }
}

function script:New-FileHash($path) {
  try {
    $hasher = New-Object System.Security.Cryptography.SHA1Cng

    $fs = New-Object System.IO.FileStream $path, 'Open', 'Read'
    return [BitConverter]::ToString($hasher.ComputeHash($fs)).Replace('-','').ToLower()
  }
  catch {
    throw "[ERROR] unable to hash $path"
  }
  finally {
    $fs.Close()
  }
}

function script:Move-ArchiveToPkg() {
  $pkg_root = "$buildlet_root/pkg"
  if (-not (Test-Path "$pkg_root" -type container)) {
    New-Item $pkg_root -itemtype directory -force | Out-Null
  }

  mv "$install_dir/$bin_archive" "$pkg_root" -force
  mv "$install_dir/$bin_archive_hash" "$pkg_root" -force
}

function Archive-Build() {
  param (
    $name = $source_dir
  )

  Push-Location "$install_dir"
    if ($x64) { $arch = '[64-bit]' }
    Write-Status "creating binary archive for ${name} ${arch}"
    if ($x64) { $arch = 'x64' } else { $arch = 'x86' }
    $script:bin_archive = "${name}-${arch}-windows-bin.7z"
    $script:bin_archive_hash = "$bin_archive.sha1"

    & "$s7z" "a" "-mx=9" "-r" $bin_archive "*" | Out-Null

    "$(New-FileHash $PWD/$bin_archive) ?SHA1*${bin_archive}" |
      Out-File -encoding ASCII $bin_archive_hash

    Move-ArchiveToPkg

  Pop-Location
}

function Clean-Build() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  Write-Status "cleaning up"
  if ($block) {
    $block.Invoke()
  } else {
    rm "${source_dir}" -recurse -force
  }

  $env:CPATH = $null
  $env:CC = $null
  $env:CXX = $null
  $env:CFLAGS = $null
  $env:LIBRARY_PATH = $null
  $env:PATH = $original_path
}

# Returns whether or not the current user has administrative privileges
function IsAdministrator
{
    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
    $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
