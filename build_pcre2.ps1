#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-12-11 19:00:58 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='PCRE2 version to build (eg - 10.36)')]
  [validateset('10.36')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'pcre2'
$source = "${libname}-${version}.tar.gz"
$build_name = "${libname}-${version}"
$repo_root = "https://ftp.pcre.org/pub/pcre/"
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
    $private:opts = @('--enable-never-backslash-C'
                      '--enable-jit'
                      '--enable-newline-is-anycrlf')
    sh -c "./configure --prefix=${install_dir} ${triplets} $($opts -join ' ')" | Out-Null
  }

  # build
  New-Build {
    sh -c 'make' | Out-Null
  }

  # install
  sh -c 'make install' | Out-Null

  # stage
  Stage-Build {
    strip --strip-unneeded "$install_dir/${libname}test.exe" | Out-Null
    strip --strip-unneeded "$install_dir/${libname}grep.exe" | Out-Null
  }

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
