# Test for the optionless vscode home module.
# Run with: nix eval --file ./vscode-test.nix
{
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;

  testPkgs = pkgs // {
    vscode-marketplace = {
      pkief.material-icon-theme = pkgs.emptyDirectory;
      zhuangtongfa.material-theme = pkgs.emptyDirectory;
      arrterian.nix-env-selector = pkgs.emptyDirectory;
      bbenoist.nix = pkgs.emptyDirectory;
      jnoortheen.nix-ide = pkgs.emptyDirectory;
      pinage404.nix-extension-pack = pkgs.emptyDirectory;
      mkhl.direnv = pkgs.emptyDirectory;
      dbaeumer.vscode-eslint = pkgs.emptyDirectory;
      davidanson.vscode-markdownlint = pkgs.emptyDirectory;
      rvest.vs-code-prettier-eslint = pkgs.emptyDirectory;
      richie5um2.vscode-sort-json = pkgs.emptyDirectory;
      tyriar.sort-lines = pkgs.emptyDirectory;
      anthropic.claude-code = pkgs.emptyDirectory;
    };
  };

  evalModule =
    {
      enable ? false,
    }:
    let
      evaluated = lib.evalModules {
        modules = [
          {
            options.programs.vscode = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                  };
                  profiles = lib.mkOption {
                    type = lib.types.attrsOf (
                      lib.types.submodule {
                        options = {
                          extensions = lib.mkOption {
                            type = lib.types.listOf lib.types.package;
                            default = [ ];
                          };
                          userSettings = lib.mkOption {
                            type = lib.types.attrs;
                            default = { };
                          };
                        };
                      }
                    );
                    default = { };
                  };
                };
              };
              default = { };
            };
            config._module.args = {
              pkgs = testPkgs;
            };
          }
        ]
        ++ lib.optional enable ../../modules/home/vscode.nix;
      };
    in
    evaluated.config;

  tests = {
    test_disabled_when_module_excluded = {
      expr =
        let
          config = evalModule { };
        in
        {
          vscodeEnabled = config.programs.vscode.enable;
          profiles = config.programs.vscode.profiles;
        };
      expected = {
        vscodeEnabled = false;
        profiles = { };
      };
    };

    test_import_sets_vscode = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        config.programs.vscode.enable;
      expected = true;
    };

    test_import_has_extensions = {
      expr =
        let
          config = evalModule { enable = true; };
        in
        {
          hasExtensions = builtins.isList config.programs.vscode.profiles.default.extensions;
          extensionCount = builtins.length config.programs.vscode.profiles.default.extensions;
        };
      expected = {
        hasExtensions = true;
        extensionCount = 13;
      };
    };

    test_import_has_user_settings_shape = {
      expr =
        let
          config = evalModule { enable = true; };
          settings = config.programs.vscode.profiles.default.userSettings;
        in
        {
          hasUserSettings = builtins.isAttrs settings;
          hasEditorSettings = settings ? "editor.fontSize";
          hasTerminalSettings = settings ? "terminal.integrated.defaultProfile.osx";
          terminalProfile = settings."terminal.integrated.defaultProfile.osx";
          hasTypescriptMemory = settings ? "typescript.tsserver.maxTsServerMemory";
        };
      expected = {
        hasUserSettings = true;
        hasEditorSettings = true;
        hasTerminalSettings = true;
        terminalProfile = "fish";
        hasTypescriptMemory = true;
      };
    };
  };

  results = lib.mapAttrs (
    name: test:
    let
      passed = test.expr == test.expected;
    in
    {
      inherit passed;
      inherit (test) expected;
      actual = test.expr;
      message =
        if passed then
          "PASS"
        else
          "FAIL: expected ${builtins.toJSON test.expected}, got ${builtins.toJSON test.expr}";
    }
  ) tests;

  allPassed = lib.all (r: r.passed) (lib.attrValues results);

  summary = {
    inherit results allPassed;
    total = lib.length (lib.attrNames tests);
    passed = lib.length (lib.filter (r: r.passed) (lib.attrValues results));
  };
in
if allPassed then
  {
    success = true;
    message = "All ${toString summary.total} tests passed!";
    inherit (summary) results;
  }
else
  {
    success = false;
    message = "Tests failed: ${toString (summary.total - summary.passed)}/${toString summary.total}";
    inherit (summary) results;
  }
