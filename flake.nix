{
  description = "GitHub labels management script";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import the labels definition
        labels = import ./labels.nix;

        # Convert Nix labels to shell-friendly format
        labelsToShellScript = labels:
          let
            makeLabel = name: data: ''
              ${pkgs.gh}/bin/gh label create "${name}" --color "${data.color}" --description "${data.description}" --repo "$REPO" || echo "Label '${name}' already exists"
              echo "  Created: ${name} (${data.color}) - ${data.description}"
            '';
            labelCmds = pkgs.lib.mapAttrsToList makeLabel labels;
          in builtins.concatStringsSep "\n" labelCmds;

        # The script to apply GitHub labels
        labelScript = pkgs.writeScriptBin "apply-github-labels" ''
          #!/usr/bin/env bash
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: $0 <owner/repo>"
            echo "Example: $0 myuser/myrepo"
            exit 1
          fi

          REPO="$1"
          echo "Applying predefined labels to $REPO..."

          # Option to delete existing labels
          if [ "$#" -gt 1 ] && [ "$2" = "--delete-existing" ]; then
            echo "Deleting existing labels..."
            ${pkgs.gh}/bin/gh label list --repo "$REPO" --json name -q '.[].name' | while read label; do
              ${pkgs.gh}/bin/gh label delete "$label" --repo "$REPO" --yes
              echo "  Deleted: $label"
            done
          fi

          # Create labels
          ${labelsToShellScript labels}

          echo "All labels have been applied to $REPO!"
        '';

      in {
        packages.default = pkgs.symlinkJoin {
          name = "github-labels-tool";
          paths = [ labelScript pkgs.gh ];
        };

        apps.default = flake-utils.lib.mkApp { drv = labelScript; };
      });
}
