#requires -version 3.0

# Author: Jon Maken
# License: 3-clause BSD
# Revision: 2020-10-12 20:53:01 -0600

param(
  [parameter(Mandatory=$true,
             Position=0,
             HelpMessage='Oniguruma version to build (eg - 6.9.6-rc2)')]
  [validateset('6.9.6-rc2')]
  [alias('v')]
  [string] $version,

  [parameter(HelpMessage='perform a 64-bit build')]
  [switch] $x64
)

$libname = 'onig'
$source = "${libname}-${version}.tar.gz"
$build_name = "${libname}-$($version.Split([char[]]'-_')[0])"
$repo_root = "https://github.com/kkos/oniguruma/releases/download/v$($version.Replace('-','_'))/"
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
    # TODO find better configure.ac and src/Makefile.am fix and submit upstream.
    #      The fix needs to create libonig*.dll and libonig.def, install to $bindir
    #      and $libdir, strip the DLL, and create lib/{libonig.a,libonig.dll.a}
    #      Need to override with `--build=x86_64-w64-mingw32` as config.guess used
    #      `x86_64-pc-msys` which disabled shared lib builds
    # https://lists.gnu.org/archive/html/libtool/2007-04/msg00066.html
    sed -i '/^libonig_la_LDFLAGS/s/^.*$/& -no-undefined/' src/Makefile.am
    sh -c 'autoreconf -fi' | Out-Null
    sh -c "./configure --prefix=${install_dir} $triplets" | Out-Null
  }

  # build
  New-Build {
    sh -c 'make' | Out-Null
  }

  # install
  sh -c 'make install' | Out-Null
  sh -c 'make -C src dll' | Out-Null  # XXX needed just to create libonig.def

  # stage
  Stage-Build {
    strip "${install_dir}/bin/lib${libname}*.dll" | Out-Null
    cp "${build_src_dir}/src/lib${libname}.def" "${install_dir}/lib" | Out-Null
  }

  # archive
  Archive-Build

Pop-Location

# cleanup
Clean-Build
