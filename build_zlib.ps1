#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-09-26 17:26:33 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='zlib version to build (eg - 1.2.11)')]
  [validateset('1.2.11')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'zlib'
$source = "${libname}-${version}.tar.gz"
$build_name = "${libname}-${version}"
$repo_root = 'https://zlib.net/'
$archive = "${repo_root}${source}"
$hash_uri = "https://raw.github.com/jonforums/buildlets/master/hashery/${libname}.md5"

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
  Configure-Build

  # build
  New-Build {
    sh -c "make -f win32/Makefile.gcc" | Out-Null
  }

  # install
  $install_opts = @("BINARY_PATH=${install_dir}/bin",
                    "INCLUDE_PATH=${install_dir}/include",
                    "LIBRARY_PATH=${install_dir}/lib",
                    "SHARED_MODE=1")
  sh -c "make install -f win32/Makefile.gcc $(${install_opts} -join ' ')" | Out-Null

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
