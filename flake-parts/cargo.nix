{inputs, ...}: {
  perSystem = {
    pkgs,
    lib,
    system,
    inputs',
    self',
    ...
  }: let
    extraPackages =
      [
        pkgs.pkg-config
        pkgs.protobufc
      ]
      ++ lib.optionals pkgs.stdenv.isDarwin [
        pkgs.libiconv
        pkgs.darwin.apple_sdk.frameworks.AppKit
        pkgs.darwin.apple_sdk.frameworks.CoreFoundation
        pkgs.darwin.apple_sdk.frameworks.CoreServices
        pkgs.darwin.apple_sdk.frameworks.Foundation
        pkgs.darwin.apple_sdk.frameworks.Security
      ];
    withExtraPackages = base: base ++ extraPackages;

    craneLib = (inputs.crane.mkLib pkgs).overrideToolchain self'.packages.rust-toolchain;

    commonArgs = rec {
      src = inputs.nix-filter.lib {
        root = ../.;
        include = [
          "src"
          "tests"
          "Cargo.toml"
          "Cargo.lock"
        ];
      };

      pname = "dash-mpd-cli";

      nativeBuildInputs = withExtraPackages [];
      LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeBuildInputs;
      PROTOC = "${pkgs.protobuf}/bin/protoc";
      doCheck = false;
    };

    cargoArtifacts = craneLib.buildDepsOnly commonArgs;

    packages = {
      default = packages.dash-mpd-cli;
      dash-mpd-cli = craneLib.buildPackage ({
          inherit cargoArtifacts;
        }
        // commonArgs);

      cargo-doc = craneLib.cargoDoc ({
          inherit cargoArtifacts;
        }
        // commonArgs);
    };

    checks = {
      clippy = craneLib.cargoClippy (commonArgs
        // {
          inherit cargoArtifacts;
          cargoClippyExtraArgs = "--all-features -- --deny warnings";
        });

      rust-fmt = craneLib.cargoFmt (commonArgs
        // {
          inherit (commonArgs) src;
        });

      rust-tests = craneLib.cargoNextest (commonArgs
        // {
          inherit cargoArtifacts;
          partitions = 1;
          partitionType = "count";
        });
    };
  in {
    inherit packages checks;

    legacyPackages = {
      cargoExtraPackages = extraPackages;
    };
  };
}
