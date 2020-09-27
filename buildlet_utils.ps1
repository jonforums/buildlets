#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-09-27 13:48:49 -0600

# save the clean path
$script:original_path = $env:PATH

# always build using a pristine PATH free of lurking customization monsters
$env:PATH = 'C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\'

# buildlet execution root directory
$script:buildlet_root = Split-Path -parent $MyInvocation.MyCommand.Path

trap {
  Clean-Build
  break
}

# parse and validate user specified toolchain configuration data
function private:Validate-Toolchain() {
  if (-not ($toolchain.buildroot)) {
    throw '[ERROR] must specify a build root directory'
  }
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

# ensure a valid toolchain definition file exists
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
  $s7z = "$buildlet_root\tools\7za.exe"
}

# customizable build dir structure, i.e. allows ramdisk based builds
$script:build_root = $toolchain.buildroot
$script:build_stage_dir = "${build_root}staging"
$script:build_src_dir = "${build_root}/${build_name}"

# ensure build root dir exists
if (-not (Test-Path "${build_root}")) {
  throw "[ERROR] build root '${build_root}' does not exist"
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
        try {
          (New-Object System.Net.WebClient).DownloadFile($archive, "$PWD\$source")
        } catch {
          throw "[ERROR] unable to fetch $archive"
        }
        break
      }
      # TODO no need for switch on ftp vs. http[s] download method if using WebClient?
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
  Write-Status "validating $source"

  if (-not (Test-Path "$PWD\$source")) {
    throw "[ERROR] no downloaded $source file to validate"
  }

  try {
    $fetcher = New-Object System.Net.WebClient
    $hash = ConvertFrom-StringData $fetcher.DownloadString($hash_uri)
  }
  catch {}

  if ($hash.Count -eq 0) {
    Write-Status "   no checksum for $source...continuing" -color 'red'
    return
  }

  switch ($hash_uri.SubString($hash_uri.LastIndexOf('.')+1)) {
    'md5' { $hasher = New-Object System.Security.Cryptography.MD5CryptoServiceProvider; break }
    'sha1' { $hasher = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider; break }
    'sha256' { $hasher = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider; break }
    'sha512' { $hasher = New-Object System.Security.Cryptography.SHA512CryptoServiceProvider; break }
    default { throw }
  }

  try {
    $fs = New-Object System.IO.FileStream "$PWD\$source", 'Open', 'Read'
    $test_hash = [BitConverter]::ToString($hasher.ComputeHash($fs)).Replace('-','').ToLower()
  }
  catch {
    throw "[ERROR] unable to validate $source"
  }
  finally {
    if ($fs) { $fs.Close() }
  }

  if ($test_hash -ne $hash[$version].ToLower()) {
    throw "[ERROR] $source fingerprint different than expected value"
  }
}

# use for extracting tar based archives
function Extract-Archive() {
  Write-Status "extracting $source"
  $tar_file = "$($source.Substring(0, $source.LastIndexOf('-')))*.tar"
  (& "$s7z" "x" "-y" $source) -and (& "$s7z" "x" "-y" $tar_file -o"${build_root}") -and (rm $tar_file) | Out-Null
}

# use for extracting zip's, non-tar based archives, and any other custom archive extractions
function Extract-CustomArchive([System.Management.Automation.ScriptBlock] $block) {
  Write-Status "extracting $source"

  if ($block) {
    $block.Invoke()
  } else {
    (& "$s7z" "x" "-y" $source -o"${build_root}") | Out-Null
  }
}

# TODO allow custom status message
function Activate-Toolchain([System.Management.Automation.ScriptBlock] $block) {
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
function Apply-Patches([System.Management.Automation.ScriptBlock] $block) {
  if ($x64) { $arch = '[64-bit]' }
  Write-Status "patching ${build_name} ${arch}"

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
function Configure-Build([System.Management.Automation.ScriptBlock] $block) {
  if ($x64) { $arch = '[64-bit]' }
  Write-Status "configuring ${build_name} ${arch}"
  $script:install_dir = "$(${build_stage_dir}.ToString().Replace('\','/'))"

  if ($block) { $block.Invoke() }
}

# TODO allow custom status message
function New-Build([System.Management.Automation.ScriptBlock] $block) {
  if ($x64) { $arch = '[64-bit]' }
  Write-Status "building ${build_name} ${arch}"

  if ($block) { $block.Invoke() }
}

# TODO allow custom status message
function Stage-Build([System.Management.Automation.ScriptBlock] $block) {
  if ($x64) { $arch = '[64-bit]' }
  Write-Status "staging ${build_name} ${arch}"

  if ($block) { $block.Invoke() }
}

function script:New-FileHash($path) {
  try {
    $hasher = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider

    $fs = New-Object System.IO.FileStream $path, 'Open', 'Read'
    return [BitConverter]::ToString($hasher.ComputeHash($fs)).Replace('-','').ToLower()
  }
  catch {
    throw "[ERROR] unable to hash $path"
  }
  finally {
    if ($fs) { $fs.Close() }
  }
}

# TODO allow custom status message
function Test-Build([System.Management.Automation.ScriptBlock] $block) {
  if ($x64) { $arch = '[64-bit]' }
  Write-Status "testing ${build_name} ${arch}"

  if ($block) { $block.Invoke() }
}

function script:Move-ArchiveToPkg() {
  $pkg_root = "$buildlet_root/pkg"
  if (-not (Test-Path "$pkg_root" -type container)) {
    New-Item $pkg_root -itemtype directory -force | Out-Null
  }

  mv "$install_dir/$bin_archive" "$pkg_root" -force
  mv "$install_dir/$bin_archive_hash" "$pkg_root" -force
}

function Archive-Build($name = $build_name, $variant = $null) {
  if (-not ($variant)) { $variant = 'bin' }
  Push-Location "$install_dir"
    if ($x64) { $arch = '[64-bit]' }
    Write-Status "creating binary archive for ${name} ${arch}"
    if ($x64) { $arch = 'x64' } else { $arch = 'x86' }
    $script:bin_archive = "${name}-${arch}-windows-${variant}.7z"
    $script:bin_archive_hash = "$bin_archive.sha256"

    & "$s7z" "a" "-mx=9" "-r" $bin_archive "*" | Out-Null

    "$(New-FileHash $PWD/$bin_archive) *${bin_archive}" |
      Out-File -encoding ASCII $bin_archive_hash

    Move-ArchiveToPkg

  Pop-Location
}

function Clean-Build([System.Management.Automation.ScriptBlock] $block) {
  Write-Status "cleaning up"
  if ($block) {
    $block.Invoke()
  } else {
    rm ${build_src_dir}, ${build_stage_dir} -recurse -force
  }

  $env:CPATH = $null
  $env:CC = $null
  $env:CXX = $null
  $env:CFLAGS = $null
  $env:CPPFLAGS = $null
  $env:LDFLAGS = $null
  $env:LIBRARY_PATH = $null
  $env:PATH = $original_path
}

# Returns whether or not the current user has administrative privileges
function IsAdministrator {
    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object System.Security.Principal.WindowsPrincipal($Identity)
    $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
