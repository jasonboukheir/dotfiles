polarity: let
  uiTheme =
    if polarity == "light"
    then "vs"
    else "vs-dark";
in {
  name = "stylix";
  displayName = "Stylix";
  description = "Stylix generated theme";
  version = "0.0.0";
  publisher = "stylix";
  engines = {
    vscode = "^1.0.0";
  };
  categories = ["Themes"];
  contributes = {
    themes = [
      {
        label = "Stylix";
        inherit uiTheme;
        path = "./themes/stylix.json";
      }
    ];
  };
}
