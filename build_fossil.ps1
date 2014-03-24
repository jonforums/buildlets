#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2014-03-24 13:10:49 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='fossil version to build (eg - 1.28)')]
  [validateset('1.28')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64,

  [parameter(HelpMessage='Path to OpenSSL dev libraries root directory')]
  [alias('with-ssl-dir')]
  [string] $SSL_DIR = 'C:/devlibs/openssl/x86/1.0.1f'
)

$libname = 'fossil'
$source = "${libname}-${version}.tar.gz"
$source_dir = "${libname}-${version}"
$repo_root = "http://www.fossil-scm.org/fossil/tarball/"
$archive = "${repo_root}${source}?uuid=version-${version}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.sha1"

# source the buildlet library
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
    $SSL_DIR = $SSL_DIR.Replace('\', '/')
    if ($SSL_DIR.ToLower() -eq 'no') { $SSL_DIR = $null }

    if ($SSL_DIR) {
      $defs = @('FOSSIL_ENABLE_SSL=1'
                "OPENSSLINCDIR=${SSL_DIR}/include"
                "OPENSSLLIBDIR=${SSL_DIR}/lib")
      $script:defines = "$($defs -join ' ')"
    }
  }

  # build
  New-Build {
    sh -c "make $defines -f win/Makefile.mingw" | Out-Null
  }

  # stage
  Stage-Build {
    New-Item "$install_dir/bin" -itemtype directory | Out-Null
    mv "${libname}.exe" "$install_dir/bin" | Out-Null
  }

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
