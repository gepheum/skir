import { autocompletion, closeBrackets } from "@codemirror/autocomplete";
import { json as jsonExtension } from "@codemirror/lang-json";
import { linter, lintGutter } from "@codemirror/lint";
import { EditorState, Extension } from "@codemirror/state";
import { EditorView } from "@codemirror/view";
import * as codeMirrorThemes from "@uiw/codemirror-themes-all";
import { basicSetup } from "codemirror";
import { makeJsonTemplate } from "../json/to_json";
import type { Json, RecordDefinition, TypeDefinition } from "../json/types";
import { enterKeyHandler } from "./enter_key_handler";
import { jsonCompletion } from "./json_completion";
import { jsonLinter } from "./json_linter";
import { debouncedJsonParser } from "./json_state";
import { statusBar } from "./status_bar";

export type CreateEditorStateParams = {
  schema: TypeDefinition;
  readOnly?: true;
  json?: Json;
  theme?: BuiltinThemeName | CustomTheme;
  otherExtension?: Extension;
};

export type BuiltinThemeName =
  | "abcdef"
  | "abyss"
  | "androidstudio"
  | "andromeda"
  | "atomone"
  | "aura"
  | "basic-dark"
  | "basic-light"
  | "bbedit"
  | "bespin"
  | "console-dark"
  | "console-light"
  | "copilot"
  | "darcula"
  | "dracula"
  | "duotone-dark"
  | "duotone-light"
  | "eclipse"
  | "github-dark"
  | "github-light"
  | "gruvbox-dark"
  | "gruvbox-light"
  | "kimbie"
  | "material"
  | "material-dark"
  | "material-light"
  | "monokai"
  | "monokai-dimmed"
  | "noctis-lilac"
  | "nord"
  | "okaidia"
  | "quietlight"
  | "red"
  | "solarized-dark"
  | "solarized-light"
  | "sublime"
  | "tokyo-night"
  | "tokyo-night-day"
  | "tokyo-night-storm"
  | "tomorrow-night-blue"
  | "vscode-dark"
  | "vscode-light"
  | "white"
  | "white-dark"
  | "white-light"
  | "xcode-dark"
  | "xcode-light";

const WHITE_THEME_COLORS: Omit<CustomTheme, "themeExtension"> = {
  backgroundColor: "#fffdf7",
  lighterBgColor: "#f3eee1",
  borderColor: "#d4d0c4",
  foregroundColor: "#111111",
  accentColor: "#111111",
  errorColor: "#232323",
  selectionColor: "#d9d4c7",
};

const TOKYO_NIGHT_THEME_COLORS: Omit<CustomTheme, "themeExtension"> = {
  backgroundColor: "#1a1b26",
  lighterBgColor: "#1f2335",
  borderColor: "#414868",
  foregroundColor: "#c0caf5",
  accentColor: "#7aa2f7",
  errorColor: "#f7768e",
  selectionColor: "#515c7e40",
};

const TOKYO_NIGHT_DAY_THEME_COLORS: Omit<CustomTheme, "themeExtension"> = {
  backgroundColor: "#d5d6db",
  lighterBgColor: "#e1e2e7",
  borderColor: "#adb0bb",
  foregroundColor: "#3760bf",
  accentColor: "#2e7de9",
  errorColor: "#f52a65",
  selectionColor: "#3760bf33",
};

type ThemeDefaults = Partial<{
  background: string;
  foreground: string;
  caret: string;
  selection: string;
  selectionMatch: string;
  gutterBackground: string;
  gutterForeground: string;
  gutterBorder: string;
  lineHighlight: string;
}>;

const BUILTIN_THEME_EXTENSIONS: Record<BuiltinThemeName, Extension> = {
  abcdef: codeMirrorThemes.abcdef,
  abyss: codeMirrorThemes.abyss,
  androidstudio: codeMirrorThemes.androidstudio,
  andromeda: codeMirrorThemes.andromeda,
  atomone: codeMirrorThemes.atomone,
  aura: codeMirrorThemes.aura,
  "basic-dark": codeMirrorThemes.basicDark,
  "basic-light": codeMirrorThemes.basicLight,
  bbedit: codeMirrorThemes.bbedit,
  bespin: codeMirrorThemes.bespin,
  "console-dark": codeMirrorThemes.consoleDark,
  "console-light": codeMirrorThemes.consoleLight,
  copilot: codeMirrorThemes.copilot,
  darcula: codeMirrorThemes.darcula,
  dracula: codeMirrorThemes.dracula,
  "duotone-dark": codeMirrorThemes.duotoneDark,
  "duotone-light": codeMirrorThemes.duotoneLight,
  eclipse: codeMirrorThemes.eclipse,
  "github-dark": codeMirrorThemes.githubDark,
  "github-light": codeMirrorThemes.githubLight,
  "gruvbox-dark": codeMirrorThemes.gruvboxDark,
  "gruvbox-light": codeMirrorThemes.gruvboxLight,
  kimbie: codeMirrorThemes.kimbie,
  material: codeMirrorThemes.material,
  "material-dark": codeMirrorThemes.materialDark,
  "material-light": codeMirrorThemes.materialLight,
  monokai: codeMirrorThemes.monokai,
  "monokai-dimmed": codeMirrorThemes.monokaiDimmed,
  "noctis-lilac": codeMirrorThemes.noctisLilac,
  nord: codeMirrorThemes.nord,
  okaidia: codeMirrorThemes.okaidia,
  quietlight: codeMirrorThemes.quietlight,
  red: codeMirrorThemes.red,
  "solarized-dark": codeMirrorThemes.solarizedDark,
  "solarized-light": codeMirrorThemes.solarizedLight,
  sublime: codeMirrorThemes.sublime,
  "tokyo-night": codeMirrorThemes.tokyoNight,
  "tokyo-night-day": codeMirrorThemes.tokyoNightDay,
  "tokyo-night-storm": codeMirrorThemes.tokyoNightStorm,
  "tomorrow-night-blue": codeMirrorThemes.tomorrowNightBlue,
  "vscode-dark": codeMirrorThemes.vscodeDark,
  "vscode-light": codeMirrorThemes.vscodeLight,
  white: codeMirrorThemes.whiteLight,
  "white-dark": codeMirrorThemes.whiteDark,
  "white-light": codeMirrorThemes.whiteLight,
  "xcode-dark": codeMirrorThemes.xcodeDark,
  "xcode-light": codeMirrorThemes.xcodeLight,
};

const BUILTIN_THEME_DEFAULTS: Record<BuiltinThemeName, ThemeDefaults> = {
  abcdef: codeMirrorThemes.defaultSettingsAbcdef,
  abyss: codeMirrorThemes.defaultSettingsAbyss,
  androidstudio: codeMirrorThemes.defaultSettingsAndroidstudio,
  andromeda: codeMirrorThemes.defaultSettingsAndromeda,
  atomone: codeMirrorThemes.defaultSettingsAtomone,
  aura: codeMirrorThemes.defaultSettingsAura,
  "basic-dark": codeMirrorThemes.defaultSettingsBasicDark,
  "basic-light": codeMirrorThemes.defaultSettingsBasicLight,
  bbedit: codeMirrorThemes.defaultSettingsBbedit,
  bespin: codeMirrorThemes.defaultSettingsBespin,
  "console-dark": codeMirrorThemes.defaultSettingsConsoleDark,
  "console-light": codeMirrorThemes.defaultSettingsConsoleLight,
  copilot: codeMirrorThemes.defaultSettingsCopilot,
  darcula: codeMirrorThemes.defaultSettingsDarcula,
  dracula: codeMirrorThemes.defaultSettingsDracula,
  "duotone-dark": codeMirrorThemes.defaultSettingsDuotoneDark,
  "duotone-light": codeMirrorThemes.defaultSettingsDuotoneLight,
  eclipse: codeMirrorThemes.defaultSettingsEclipse,
  "github-dark": codeMirrorThemes.defaultSettingsGithubDark,
  "github-light": codeMirrorThemes.defaultSettingsGithubLight,
  "gruvbox-dark": codeMirrorThemes.defaultSettingsGruvboxDark,
  "gruvbox-light": codeMirrorThemes.defaultSettingsGruvboxLight,
  kimbie: codeMirrorThemes.defaultSettingsKimbie,
  material: codeMirrorThemes.defaultSettingsMaterial,
  "material-dark": codeMirrorThemes.defaultSettingsMaterialDark,
  "material-light": codeMirrorThemes.defaultSettingsMaterialLight,
  monokai: codeMirrorThemes.defaultSettingsMonokai,
  "monokai-dimmed": codeMirrorThemes.defaultSettingsMonokaiDimmed,
  "noctis-lilac": codeMirrorThemes.defaultSettingsNoctisLilac,
  nord: codeMirrorThemes.defaultSettingsNord,
  okaidia: codeMirrorThemes.defaultSettingsOkaidia,
  quietlight: codeMirrorThemes.defaultSettingsQuietlight,
  red: codeMirrorThemes.defaultSettingsRed,
  "solarized-dark": codeMirrorThemes.defaultSettingsSolarizedDark,
  "solarized-light": codeMirrorThemes.defaultSettingsSolarizedLight,
  sublime: codeMirrorThemes.defaultSettingsSublime,
  "tokyo-night": codeMirrorThemes.defaultSettingsTokyoNight,
  "tokyo-night-day": codeMirrorThemes.defaultSettingsTokyoNightDay,
  "tokyo-night-storm": codeMirrorThemes.defaultSettingsTokyoNightStorm,
  "tomorrow-night-blue": codeMirrorThemes.defaultSettingsTomorrowNightBlue,
  "vscode-dark": codeMirrorThemes.defaultSettingsVscodeDark,
  "vscode-light": codeMirrorThemes.defaultSettingsVscodeLight,
  white: codeMirrorThemes.defaultSettingsWhiteLight,
  "white-dark": codeMirrorThemes.defaultSettingsWhiteDark,
  "white-light": codeMirrorThemes.defaultSettingsWhiteLight,
  "xcode-dark": codeMirrorThemes.defaultSettingsXcodeDark,
  "xcode-light": codeMirrorThemes.defaultSettingsXcodeLight,
};

function pickColor(
  ...candidates: Array<string | undefined>
): string | undefined {
  for (const candidate of candidates) {
    if (candidate && candidate !== "transparent") {
      return candidate;
    }
  }
  return undefined;
}

function themeFromDefaults(
  defaults: ThemeDefaults,
  themeExtension: Extension,
): CustomTheme {
  const background = pickColor(defaults.background, defaults.gutterBackground);
  const foreground = pickColor(
    defaults.caret,
    defaults.foreground,
    defaults.gutterForeground,
  );
  const selection = pickColor(
    defaults.selection,
    defaults.selectionMatch,
    defaults.lineHighlight,
  );
  return {
    backgroundColor: background ?? "#1a1b26",
    lighterBgColor:
      pickColor(
        defaults.gutterBackground,
        defaults.lineHighlight,
        background,
      ) ?? "#1f2335",
    borderColor:
      pickColor(
        defaults.gutterBorder,
        defaults.selectionMatch,
        defaults.selection,
        defaults.foreground,
      ) ?? "#414868",
    foregroundColor: foreground ?? "#c0caf5",
    accentColor: pickColor(defaults.foreground, defaults.caret) ?? "#7aa2f7",
    errorColor: pickColor(defaults.caret, defaults.foreground) ?? "#f7768e",
    selectionColor: selection ?? "#515c7e40",
    themeExtension,
  };
}

function resolveBuiltinTheme(themeName: BuiltinThemeName): CustomTheme {
  const themeExtension = BUILTIN_THEME_EXTENSIONS[themeName];
  if (themeName === "white") {
    return {
      ...WHITE_THEME_COLORS,
      themeExtension,
    };
  }
  if (themeName === "tokyo-night") {
    return {
      ...TOKYO_NIGHT_THEME_COLORS,
      themeExtension,
    };
  }
  if (themeName === "tokyo-night-day") {
    return {
      ...TOKYO_NIGHT_DAY_THEME_COLORS,
      themeExtension,
    };
  }
  return themeFromDefaults(BUILTIN_THEME_DEFAULTS[themeName], themeExtension);
}

export function createEditorState({
  schema,
  readOnly,
  json,
  theme,
  otherExtension,
}: CreateEditorStateParams): EditorState {
  const idToRecordDef: { [id: string]: RecordDefinition } = {};
  for (const record of schema.records) {
    idToRecordDef[record.id] = record;
  }
  const content = json ?? makeJsonTemplate(schema.type, idToRecordDef);

  if (theme === undefined) {
    theme = resolveBuiltinTheme("tokyo-night");
  } else if (typeof theme === "string") {
    theme = resolveBuiltinTheme(theme);
  }

  return EditorState.create({
    doc: JSON.stringify(content, null, 2),
    extensions: [
      EditorState.readOnly.of(!!readOnly),
      readOnly ? [] : enterKeyHandler(schema),
      basicSetup,
      EditorState.languageData.of(() => [
        {
          closeBrackets: { before: ",]}" },
        },
      ]),
      closeBrackets(),
      theme.themeExtension ?? [],
      jsonExtension(),
      debouncedJsonParser(schema),
      linter(jsonLinter(readOnly ? "read-only" : "editable")),
      autocompletion({
        override: [jsonCompletion(schema)],
      }),
      lintGutter(),
      statusBar(),
      EditorView.theme({
        "&": {
          fontSize: "14px",
          height: "100%",
        },
        ".cm-scroller": {
          fontFamily: "'JetBrains Mono', monospace",
          overflow: "auto",
        },
        ".cm-lintRange-info": {
          backgroundImage: "none",
        },
        ".cm-lintRange-info:hover": {
          backgroundColor: theme.selectionColor,
        },
        ".cm-lintRange-error": {
          backgroundImage: "none",
          borderBottom: `3px solid ${theme.errorColor}`,
        },
        ".cm-tooltip-hover": {
          backgroundColor: theme.lighterBgColor,
          border: `1px solid ${theme.borderColor}`,
          borderRadius: "4px",
          padding: "8px 12px",
          boxShadow: "0 4px 12px rgba(0, 0, 0, 0.5)",
          fontSize: "14px",
          lineHeight: "1.4",
          color: theme.foregroundColor,
        },
        ".cm-tooltip.cm-tooltip-lint": {
          backgroundColor: theme.lighterBgColor,
          border: `1px solid ${theme.borderColor}`,
          borderRadius: "4px",
          padding: "8px 12px",
          boxShadow: "0 4px 12px rgba(0, 0, 0, 0.5)",
          fontSize: "14px", // Ensure consistency
          color: theme.foregroundColor,
        },
        ".cm-tooltip-lint .cm-diagnostic-error": {
          fontWeight: "bold",
          color: theme.errorColor,
        },
        ".cm-status-bar": {
          backgroundColor: theme.lighterBgColor,
          borderTopColor: theme.borderColor,
          color: theme.accentColor,
        },
        ".cm-diagnostic-textarea": {
          backgroundColor: theme.lighterBgColor,
          borderColor: theme.borderColor,
          color: theme.foregroundColor,
        },
        ".cm-diagnostic-textarea[readonly]": {
          backgroundColor: theme.backgroundColor,
        },
        ".cm-diagnostic-input": {
          backgroundColor: theme.lighterBgColor,
          borderColor: theme.borderColor,
          color: theme.foregroundColor,
        },
        ".cm-diagnostic-button": {
          backgroundColor: theme.lighterBgColor,
          borderColor: theme.borderColor,
          color: theme.foregroundColor,
        },
        ".cm-diagnostic-button:hover": {
          backgroundColor: theme.borderColor,
        },
        ".cm-diagnostic-error-message": {
          color: theme.errorColor,
        },
        ".diagnostic-row + .diagnostic-row": {
          borderTopColor: theme.borderColor,
        },
      }),
      EditorView.baseTheme({
        ".cm-lint-marker-info": {
          display: "none",
        },
        ".cm-status-bar": {
          display: "flex",
          flexDirection: "row-reverse",
          justifyContent: "flex-end",
          padding: "4px 12px",
          borderTop: "1px solid",
          fontSize: "12px",
          height: "16px",
        },
        ".cm-status-bar-link": {
          textDecoration: "none",
          cursor: "pointer",
        },
        ".cm-status-bar-link:hover": {
          textDecoration: "underline",
        },
        ".cm-status-bar-link:hover ~ .cm-status-bar-link": {
          textDecoration: "underline",
        },
        ".cm-diagnostic-wrapper": {
          fontSize: "12px",
          lineHeight: "1.3",
          padding: "2px",
        },
        ".cm-diagnostic-controls": {
          marginTop: "4px",
          display: "flex",
          gap: "6px",
          alignItems: "center",
        },
        ".cm-diagnostic-label": {
          whiteSpace: "nowrap",
          fontWeight: "500",
          minWidth: "64px",
        },
        ".cm-diagnostic-textarea": {
          flex: "1",
          padding: "3px 6px",
          border: "1px solid",
          borderRadius: "3px",
          fontSize: "12px",
          fontFamily: "'JetBrains Mono', monospace",
          resize: "none",
          overflow: "auto",
          boxSizing: "border-box",
        },
        ".cm-diagnostic-textarea[readonly]": {
          cursor: "default",
        },
        ".cm-diagnostic-input": {
          padding: "3px 6px",
          border: "1px solid",
          borderRadius: "3px",
          fontSize: "12px",
          fontFamily: "'JetBrains Mono', monospace",
          boxSizing: "border-box",
          width: "100%",
        },
        ".cm-diagnostic-button": {
          padding: "3px 12px",
          border: "1px solid",
          borderRadius: "3px",
          fontSize: "12px",
          fontFamily: "'JetBrains Mono', monospace",
          cursor: "pointer",
          boxSizing: "border-box",
        },
        ".cm-diagnostic-button:active": {
          transform: "translateY(1px)",
        },
        ".cm-diagnostic-error-message": {
          fontSize: "11px",
          marginTop: "2px",
          fontWeight: "500",
        },
        ".cm-timestamp-field": {
          display: "flex",
          flexDirection: "column",
          gap: "2px",
          flex: "1",
        },
        ".cm-tooltip-lint .cm-diagnostic": {
          padding: "0",
          borderTop: "none",
          borderLeft: "none",
        },
        ".cm-tooltip-lint .cm-diagnostic-error": {
          borderLeft: "none",
          fontWeight: "bold",
        },
        ".cm-tooltip-lint .cm-diagnostic-info": {
          borderLeft: "none",
        },
        ".diagnostic-row + .diagnostic-row": {
          marginTop: "8px",
          paddingTop: "8px",
          borderTop: "1px solid",
        },
      }),
      otherExtension ?? [],
    ],
  });
}

export interface CustomTheme {
  backgroundColor: string;
  lighterBgColor: string;
  borderColor: string;
  foregroundColor: string;
  accentColor: string;
  errorColor: string;
  selectionColor: string;
  themeExtension?: Extension;
}
