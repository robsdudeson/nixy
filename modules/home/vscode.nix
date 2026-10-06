# NOTE: extension resolution uses `pkgs.vscode-marketplace`, which requires
# the nix-vscode-extensions overlay (github:nix-community/nix-vscode-extensions)
# to be applied to pkgs. The WSL host does not enable this module — VS Code
# runs on the Windows side and connects via remote-WSL — so no such overlay is
# wired into the public NixOS line.
{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;

    profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        # Themes & icons
        pkief.material-icon-theme
        zhuangtongfa.material-theme

        # Nix language support
        arrterian.nix-env-selector
        bbenoist.nix
        jnoortheen.nix-ide
        pinage404.nix-extension-pack

        # Development tools
        mkhl.direnv

        # Linters & formatters referenced in settings
        dbaeumer.vscode-eslint
        davidanson.vscode-markdownlint
        rvest.vs-code-prettier-eslint

        # Utilities
        richie5um2.vscode-sort-json
        tyriar.sort-lines

        # AI tools
        anthropic.claude-code
      ];

      userSettings = {
        # Language-specific formatters
        "[javascript]"."editor.defaultFormatter" = "dbaeumer.vscode-eslint";
        "[json]"."editor.defaultFormatter" = "vscode.json-language-features";
        "[jsonc]"."editor.defaultFormatter" = "vscode.json-language-features";
        "[markdown]"."editor.defaultFormatter" = "DavidAnson.vscode-markdownlint";
        "[typescript]"."editor.defaultFormatter" = "rvest.vs-code-prettier-eslint";
        "[typescriptreact]"."editor.defaultFormatter" = "vscode.typescript-language-features";

        # Editor settings
        "editor.fontFamily" =
          "FiraCode-Retina, Fira Code Retina, Fira Code, Fira Mono Regular, MesloLGL Nerd Font Mono, Hack Nerd Font Mono, Menlo, Monaco, 'Courier New', monospace";
        "editor.fontLigatures" = true;
        "editor.fontSize" = 11;
        "editor.formatOnPaste" = true;
        "editor.minimap.autohide" = "mouseover";
        "editor.mouseWheelZoom" = true;
        "editor.tabSize" = 2;
        "editor.insertSpaces" = true;
        "editor.codeActionsOnSave" = {
          "source.fixAll.eslint" = "explicit";
        };

        # ESLint settings
        "eslint.format.enable" = true;
        "eslint.ignoreUntitled" = true;
        "eslint.useFlatConfig" = true;
        "eslint.validate" = [
          "javascript"
          "javascriptreact"
          "typescript"
          "typescriptreact"
        ];
        "eslint.workingDirectories" = [ { mode = "auto"; } ];

        # Git settings
        "git.openRepositoryInParentFolders" = "always";

        # Explorer settings
        "explorer.confirmDelete" = false;

        # Search settings
        "search.showLineNumbers" = true;

        # Security settings
        "security.workspace.trust.untrustedFiles" = "open";

        # Terminal settings
        "terminal.explorerKind" = "both";
        "terminal.integrated.defaultProfile.osx" = "fish";
        "terminal.integrated.enablePersistentSessions" = false;
        "terminal.integrated.fontLigatures.enabled" = true;
        "terminal.integrated.ignoreProcessNames" = [
          "starship"
          "oh-my-posh"
          "bash"
          "zsh"
        ];
        "terminal.integrated.scrollback" = 100000;
        "terminal.integrated.shellIntegration.enabled" = false;
        "terminal.integrated.shellIntegration.environmentReporting" = true;
        "terminal.integrated.suggest.enabled" = true;

        # TypeScript settings
        "typescript.preferences.includePackageJsonAutoImports" = "off";
        "typescript.suggestionActions.enabled" = true;
        "typescript.tsserver.maxTsServerMemory" = 8192;
        "typescript.validate.enable" = true;

        # Python settings
        "python.analysis.typeCheckingMode" = "strict";

        # Workbench settings
        "workbench.colorTheme" = "One Dark Pro Darker";
        "workbench.iconTheme" = "material-icon-theme";
        "workbench.panel.showLabels" = false;

        # Diff editor settings
        "diffEditor.ignoreTrimWhitespace" = false;
      };
    };
  };
}
