#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2014-01-20 20:47:21 -0600

# save the clean path
$script:original_path = $env:PATH

# buildlet execution root directory
$buildlet_root = Split-Path -parent $MyInvocation.MyCommand.Path

# parse and validate user specified toolchain configuration data
function private:Validate-Toolchain() {
  if (-not ($toolchain.x32)) {
    throw '[ERROR] must provide a 32-bit toolchain configuration'
  }
  if (-not ($toolchain.x32.path)) {
    throw '[ERROR] must provide PATH information for the 32-bit toolchain'
  }
  if ($toolchain.x32.path -isnot [System.Array]) {
    throw '[ERROR] 32-bit toolchain PATH info must be in an array'
  }
  if (-not ($toolchain.x32.path.count -gt 0)) {
    throw '[ERROR] 32-bit toolchain PATH array must contain paths'
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
  (& "$s7z" "x" $source) -and (& "$s7z" "x" $tar_file) -and (rm $tar_file) | Out-Null
}

function Extract-CustomArchive {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  Write-Status "extracting $source"

  if ($block) {
    $block.Invoke()
  } else {
    (& "$s7z" "x" $source -o"${source_dir}") | Out-Null
  }
}

# TODO allow custom status message
function Activate-Toolchain() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  if ($x64) { $arch = '[64-bit]' }
  Write-Status "activating toolchain ${arch}"
  $new_path = $toolchain.x32.path -join ';'
  if ($x64) {
    if (-not $toolchain.x64) {
      throw '[ERROR] must provide 64-bit toolchain configuration'
    }
    $new_path = $toolchain.x64.path -join ';'
  }
  $env:PATH = "${new_path};${env:PATH}"

  if ($block) { $block.Invoke() }
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
  Write-Status "cleaning up"
  rm "${source_dir}" -recurse -force
  $env:PATH = $original_path
}
