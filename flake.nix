# flake.nix
{
  description = "Apply predefined GitHub labels to a repository using gh CLI";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs/nixos-unstable"; # Or choose a specific Nixpkgs version
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        labels = {
          "bug" = {
            color = "d73a4a";
            description = "Something isn't working";
          };
          "enhancement" = {
            color = "a2eeef";
            description = "New feature or request";
          };
          "documentation" = {
            color = "0075ca";
            description = "Improvements or additions to documentation";
          };
          "question" = {
            color = "d876e3";
            description = "Further information is requested";
          };
          "good first issue" = {
            color = "7057ff";
            description = "Good for newcomers";
          };
          "help wanted" = {
            color = "008672";
            description = "Extra attention is needed";
          };
          "priority: high" = {
            color = "b60205";
            description = "High priority issue that needs urgent attention";
          };
          "priority: medium" = {
            color = "fbca04";
            description = "Medium priority issue";
          };
          "priority: low" = {
            color = "0e8a16";
            description = "Low priority issue";
          };
          "wontfix" = {
            color = "ffffff";
            description = "This will not be worked on";
          };
        };

        # --- Bash Script Content ---
        scriptContent = ''
          #!/usr/bin/env bash
          set -euo pipefail # Exit on error, unset var, pipe failure

          # Check if gh is available and logged in
          if ! gh auth status &> /dev/null; then
            echo "Error: GitHub CLI ('gh') not installed or not logged in." >&2
            echo "Please run 'gh auth login' first." >&2
            exit 1
          fi

          # Check if repo argument is provided
          if [[ $# -ne 1 ]]; then
              echo "Usage: apply-labels <owner/repo>" >&2
              echo "Example: apply-labels nix-community/apply-labels-flake" >&2
              exit 1
          fi

          REPO="$1"
          # Basic validation of repo format
          if [[ ! "$REPO" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
             echo "Error: Invalid repository format. Expected <owner/repo>." >&2
             exit 1
          fi

          echo "Target repository: $REPO"
          echo "Applying predefined labels..."

          # Dynamically generate the label creation commands from the Nix attribute set
          ${pkgs.lib.generators.toKeyValue pkgs.lib.escapeShellArgs {
            mkKeyValue = name: value: ''
              echo " -> Applying label: '${name}' (Color: #${value.color}, Desc: '${value.description}')"
              # Use 'gh label create' - it updates the label if it already exists
              if ! gh label create "${name}" \
                    --repo "${REPO}" \
                    --color "${value.color}" \
                    --description "${value.description}"; then
                 echo "Warning: Failed to apply label '${name}'. It might already exist with protected settings or there was another API issue." >&2
                 # Continue with the next label instead of exiting
              fi
            '';
          } labels}

          echo "Finished applying labels to $REPO."
          echo "Note: If a label already existed, its color and description have been updated to match the definition."
        ''; # End of scriptContent

      in {
        # The package containing the script
        packages.default = pkgs.writeShellScriptBin "apply-labels" ''
          # Ensure gh and necessary coreutils are in PATH
          export PATH=${
            pkgs.lib.makeBinPath [ pkgs.github-cli pkgs.coreutils pkgs.gnused ]
          }:$PATH
          ${scriptContent}
        '';

        # The app definition to run the script via 'nix run'
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/apply-labels";
        };
      });
}
