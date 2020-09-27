#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-09-26 18:20:59 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='fossil version to build (eg - 2.12.1)')]
  [validateset('2.12.1')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64,

  [parameter(HelpMessage='path to OpenSSL dev library root directory')]
  [alias('with-ssl-dir')]
  [string] $SSL_DIR = 'C:/devlibs/openssl/x86/1.1.1h'
)

$libname = 'fossil'
$source = "${libname}-src-${version}.tar.gz"
$build_name = "${libname}-${version}"
$repo_root = "https://fossil-scm.org/home/uv/"
$archive = "${repo_root}${source}"
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
Push-Location "${build_src_dir}"

  # activate toolchain
  Activate-Toolchain

  # configure
  Configure-Build {
    $SSL_DIR = $SSL_DIR.Replace('\', '/')
    if ($SSL_DIR.ToLower() -eq 'no') { $SSL_DIR = $null }

    $defs = [System.Collections.ArrayList]@('FOSSIL_ENABLE_JSON=1')
    if ($x64) { $defs += 'X64=1' }
    if ($SSL_DIR) {
      # statically link OpenSSL libs
      sed -i '/^LIB += -lssl/c LIB += -l:libssl.a -l:libcrypto.a -lgdi32 -lcrypt32' win/Makefile.mingw

      $defs += @('FOSSIL_ENABLE_SSL=1'
                 "OPENSSLINCDIR=${SSL_DIR}/include"
                 "OPENSSLLIBDIR=${SSL_DIR}/lib")
    }
    $script:defines = "$($defs -join ' ')"
  }

  # build
  New-Build {
    sh -c "make $defines -f win/Makefile.mingw" | Out-Null
  }

  # stage
  Stage-Build {
    New-Item "$install_dir/bin" -itemtype directory | Out-Null
    mv "${libname}.exe" "$install_dir/bin" | Out-Null
    strip --strip-unneeded "$install_dir/bin/${libname}.exe" | Out-Null
  }

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
