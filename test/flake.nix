{
  inputs.solc.url = "..";

  outputs = { self, nixpkgs, solc }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [
        solc.overlay
      ];
    };
  in {
    devShell.x86_64-linux = with pkgs; mkShell {
      buildInputs = [
        solc_0_4_26
        solc_0_7_6
        solc_0_8_25
        (solc.mkDefault pkgs solc_0_8_19)
      ];
    };
    devShell.x86_64-darwin = with pkgs; mkShell {
      buildInputs = [
        solc_0_8_25
      ];
    };
  };
}
