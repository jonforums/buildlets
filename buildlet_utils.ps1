#requires -version 2.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2013-03-22 14:13:07 -0600

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
