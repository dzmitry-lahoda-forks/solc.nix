# based on nixpkgs/pkgs/development/compilers/solc/default.nix
{
  lib,
  gccStdenv,
  fetchzip,
  boost,
  cmake,
  coreutils,
  fetchpatch,
  jq,
  ncurses,
  python3,
  fetchurl,
  version ? "0.8.23",
  sha256 ? "sha256-9GIDfjkjDFrZQ0uqopDycMWYUN+M9yLF9NpOgSksXqI=",
  z3Support ? true,
  z3_4_11 ? null,
  cvc4Support ? gccStdenv.isLinux,
  cvc4 ? null,
  cln ? null,
  gmp ? null,
}:

# compiling source/libsmtutil/CVC4Interface.cpp breaks on clang on Darwin,
# general commandline tests fail at abiencoderv2_no_warning/ on clang on NixOS
let
  z3 = z3_4_11;
in

assert z3Support -> z3 != null && lib.versionAtLeast z3.version "4.11.0";
assert cvc4Support -> cvc4 != null && cln != null && gmp != null;

let
  jsoncppVersion = "1.9.3";
  jsoncppUrl = "https://github.com/open-source-parsers/jsoncpp/archive/${jsoncppVersion}.tar.gz";
  jsoncpp = fetchzip {
    url = jsoncppUrl;
    sha256 = "1vbhi503rgwarf275ajfdb8vpdcbn1f7917wjkf8jghqwb1c24lq";
  };

  range3Version = "0.12.0";
  range3Url = "https://github.com/ericniebler/range-v3/archive/${range3Version}.tar.gz";
  range3 = fetchzip {
    url = range3Url;
    sha256 = "sha256-bRSX91+ROqG1C3nB9HSQaKgLzOHEFy9mrD2WW3PRBWU=";
  };

  fmtlibVersion = "9.1.0";
  fmtlibUrl = "https://github.com/fmtlib/fmt/archive/${fmtlibVersion}.tar.gz";
  fmtlib = fetchzip {
    url = fmtlibUrl;
    sha256 = "sha256-rP6ymyRc7LnKxUXwPpzhHOQvpJkpnRFOt2ctvUNlYI0=";
  };

  pname = "solc";
  meta = with lib; {
    description = "Compiler for Ethereum smart contract language Solidity";
    homepage = "https://github.com/ethereum/solidity";
    license = licenses.gpl3;
    maintainers = with maintainers; [
      dbrock
      akru
      lionello
      sifmelcara
    ];
    mainProgram = "solc-${solc_ver}";
  };

  solc = gccStdenv.mkDerivation rec {
    inherit pname version meta;

    # upstream suggests avoid using archive generated by github
    src = fetchzip {
      url = "https://github.com/ethereum/solidity/releases/download/v${version}/solidity_${version}.tar.gz";
      inherit sha256;
    };

    postPatch = ''
      substituteInPlace cmake/jsoncpp.cmake \
        --replace "${jsoncppUrl}" ${jsoncpp}
      substituteInPlace cmake/range-v3.cmake \
        --replace "${range3Url}" ${range3}
      substituteInPlace cmake/fmtlib.cmake \
        --replace "${fmtlibUrl}" ${fmtlib}
    '';

    cmakeFlags =
      [ "-DBoost_USE_STATIC_LIBS=OFF" ]
      ++ (if z3Support then [ "-DSTRICT_Z3_VERSION=OFF" ] else [ "-DUSE_Z3=OFF" ])
      ++ lib.optionals (!cvc4Support) [ "-DUSE_CVC4=OFF" ];

    nativeBuildInputs = [ cmake ];
    buildInputs =
      [ boost ]
      ++ lib.optionals z3Support [ z3 ]
      ++ lib.optionals cvc4Support [
        cvc4
        cln
        gmp
      ];
    nativeCheckInputs = [
      jq
      ncurses
      (python3.withPackages (
        ps: with ps; [
          colorama
          deepdiff
          devtools
          docopt
          docutils
          requests
          sphinx
          tabulate
          z3-solver
        ]
      ))
    ]; # contextlib2 glob2 textwrap3 traceback2 urllib3

    # tests take 60+ minutes to complete, only run as part of passthru tests
    doCheck = false;

    checkPhase = ''
      pushd ..
      # IPC tests need aleth avaliable, so we disable it
      sed -i "s/IPC_ENABLED=true/IPC_ENABLED=false\nIPC_FLAGS=\"--no-ipc\"/" ./scripts/tests.sh
      for i in ./scripts/*.sh ./scripts/*.py ./test/*.sh ./test/*.py; do
        patchShebangs "$i"
      done
      ## TODO: reenable tests below after adding evmone and hera and their dependencies to nixpkgs
      #TERM=xterm ./scripts/tests.sh ${lib.optionalString z3Support "--no-smt"}
      popd
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/solc --version > /dev/null
    '';

    passthru.tests = {
      solcWithTests = solc.overrideAttrs (attrs: {
        doCheck = true;
      });
    };
  };
in
solc
