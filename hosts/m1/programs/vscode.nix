{ inputs, pkgs, ... }:
let
  nix-vscode-extensions = inputs.nix-vscode-extensions.extensions.${pkgs.system};
  marketplace-extensions = nix-vscode-extensions.vscode-marketplace;
in
{
  home-manager.users.jasonbk = {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      extensions =
        with pkgs.vscode-extensions;
        [
          jnoortheen.nix-ide
          pkief.material-icon-theme
          ms-dotnettools.vscode-dotnet-runtime
          ms-dotnettools.csharp
          ms-dotnettools.csdevkit
          ms-python.python
        ]
        ++ (with marketplace-extensions; [
          visualstudiotoolsforunity.vstuc
          marlosirapuan.nord-deep
          huytd.nord-light
        ]);

      userSettings = {
        editor = {
          acceptSuggestionOnCommitCharacter = false;
          acceptSuggestionOnEnter = "off";
          accessibilitySupport = "off";
          codeLens = true;
          colorDecorators = true;
          cursorBlinking = "phase";
          cursorStyle = "underline";
          emptySelectionClipboard = false;
          fontFamily = "'FiraCode Nerd Font'";
          fontLigatures = true;
          fontSize = 12;
          fontWeight = "500";
          formatOnPaste = true;
          formatOnSave = true;
          lightbulb.enabled = "off";
          minimap.enabled = false;
          multiCursorModifier = "alt";
          renderWhitespace = "selection";
          smoothScrolling = true;
          snippetSuggestions = "top";
          tabCompletion = "onlySnippets";
          tabSize = 4;
          tokenColorCustomizations."[Nord]".textMateRules = [ ];
          wordWrapColumn = 120;
        };
        explorer = {
          autoReveal = true;
          incrementalNaming = "smart";
          openEditors.visible = 0;
        };
        extensions = {
          closeExtensionDetailsOnViewChange = true;
        };
        files = {
          eol = "\n";
          insertFinalNewline = true;
        };
        problems = {
          autoReveal = false;
        };
        security.workspace.trust.untrustedFiles = "open";
        search = {
          collapseResults = "alwaysCollapse";
          useGlobalIgnoreFiles = true;
        };
        telemetry.telemetryLevel = "off";
        terminal = {
          explorerKind = "external";
          external = {
            linuxExec = "tilix";
            osxExex = "kitty";
          };
          integrated = {
            cursorStyle = "underline";
            fontSize = 12;
          };
        };
        window = {
          autoDetectColorScheme = true;
          autoDetectHighContrast = false;
          enableMenuBarMnemonics = false;
          menuBarVisibility = "hidden";
          titleBarStyle = "native";
        };
        workbench = {
          activityBar.visible = true;
          colorCustomizations."[Nord]" = { };
          colorTheme = "Nord Deep";
          preferredDarkColorTheme = "Nord Deep";
          preferredLightColorTheme = "Nord Light";
          commandPalette.preserveInput = true;
          editor = {
            enablePreview = false;
            enablePreviewFromQuickOpen = false;
            focusRecentEditorAfterClose = false;
          };
          enableExperiments = false;
          iconTheme = "material-icon-theme";
          quickOpen.preserveInput = true;
          settings.enableNaturalLanguageSearch = false;
          sideBar.location = "left";
          startupEditor = "welcomePage";
          statusBar.feedback.visible = false;
          renderIndentGuides = "none";
        };

        # Extensions
        "material-icon-theme" = {
          activeIconPack = "react";
          folders = {
            color = "#616e88";
            theme = "classic";
          };
          hideExplorerArrows = true;
          saturation = 0.6;
        };

        nix = {
          formatterPath = "nixfmt";
        };
      };
    };
  };
}
