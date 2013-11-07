#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-11-07 16:21:17 -0600

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
  if ($toolchain.x64) {
    if (-not ($toolchain.x64.path)) {
      throw '[ERROR] must provide PATH information for the 64-bit toolchain'
    }
    if ($toolchain.x64.path -isnot [System.Array]) {
      throw '[ERROR] 64-bit toolchain PATH info must be in an array'
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
  throw $Error[0]
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

  Write-Status "activating toolchain"
  if (-not ($block)) {
    $new_path = $toolchain.x32.path -join ';'
    if ($x64) {
      $new_path = $toolchain.x64.path -join ';'
    }
    $env:PATH = "${new_path};${env:PATH}"
  }

  if ($block) { $block.Invoke() }
}

# TODO allow custom status message
function Configure-Build() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  Write-Status "configuring ${source_dir}"
  $script:install_dir = "$($PWD.ToString().Replace('\','/'))/my_install"

  if ($block) { $block.Invoke() }
}

# TODO allow custom status message
function New-Build() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  Write-Status "building ${source_dir}"

  if ($block) { $block.Invoke() }
}

# TODO allow custom status message
function Stage-Build() {
  param (
    [System.Management.Automation.ScriptBlock] $block
  )

  Write-Status "staging ${source_dir}"

  if ($block) { $block.Invoke() }
}

function Archive-Build() {
  Push-Location "$install_dir"
    Write-Status "creating binary archive for ${source_dir}"
    $script:bin_archive = "${source_dir}-x86-windows-bin.7z"
    & "$s7z" "a" "-mx=9" "-r" $bin_archive "*" | Out-Null
  Pop-Location
}

function Move-ArchiveToRoot() {
  mv "$install_dir/$bin_archive" "$buildlet_root" -force
}

function Clean-Build() {
  Write-Status "cleaning up"
  rm "${source_dir}" -recurse -force
  $env:PATH = $original_path
}
