#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-21 22:18:46 -0600

function Write-Status($msg, $leader='--->', $color='Yellow') {
  Write-Host "$leader $msg" -foregroundcolor $color
}

function Fetch-Archive() {
  if (-not (Test-Path $source)) {
    Import-Module BitsTransfer
    Write-Status "downloading $archive"
    Start-BitsTransfer $archive "$PWD\$source"
  }
}

function Validate-Archive() {
  try {
    Write-Status "validating $source"
    $fetcher = New-Object System.Net.WebClient
    $hash = ConvertFrom-StringData $fetcher.DownloadString($hash_uri)

    $hasher = New-Object System.Security.Cryptography.SHA1Cng
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
  (& "$7ZA" "x" $source) -and (& "$7ZA" "x" $tar_file) -and (rm $tar_file) | Out-Null
}

function Activate-Toolchain() {
  # TODO return if already active on $env:PATH
  Write-Status "activating toolchain"
  . "$DEVKIT/devkitvars.ps1" | Out-Null
}

function Archive-Build() {
  Push-Location "$install_dir"
    Write-Status "creating binary archive for ${source_dir}"
    $script:bin_archive = "${source_dir}-x86-windows-bin.7z"
    & "$7ZA" "a" "-mx=9" "-r" $bin_archive "*" | Out-Null
  Pop-Location
}

function Clean-Build() {
  Write-Status "cleaning up"
  mv "$install_dir/$bin_archive" "$PWD" -force
  rm "${source_dir}" -recurse -force
}
