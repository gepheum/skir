import type { Extension } from "@codemirror/state";
import { EditorView } from "@codemirror/view";
import { whiteLight } from "@uiw/codemirror-theme-white";
import type { CustomTheme } from "skir-codemirror-plugin";

export const whiteEditorThemeExtension: Extension = [
  whiteLight,
  EditorView.theme({
    "&": {
      height: "100%",
      fontSize: "14px",
    },
    ".cm-scroller": {
      fontFamily: "'IBM Plex Mono', monospace",
    },
    ".cm-gutters": {
      borderRight: "1px solid #d4d0c4",
      backgroundColor: "#f7f3e8",
      color: "#746f63",
    },
    ".cm-activeLine, .cm-activeLineGutter": {
      backgroundColor: "#f3eee1",
    },
    ".cm-selectionBackground, &.cm-focused .cm-selectionBackground, ::selection":
      {
        backgroundColor: "#d9d4c7",
      },
    ".cm-tooltip": {
      border: "1px solid #232323",
      backgroundColor: "#fffdf7",
      color: "#111111",
    },
    ".cm-tooltip-autocomplete ul li[aria-selected]": {
      backgroundColor: "#111111",
      color: "#fffdf7",
    },
    ".cm-panels": {
      backgroundColor: "#f3eee1",
      color: "#111111",
    },
    ".cm-searchMatch": {
      backgroundColor: "#ece7da",
      outline: "1px solid #232323",
    },
    ".cm-searchMatch.cm-searchMatch-selected": {
      backgroundColor: "#d9d4c7",
    },
    ".cm-matchingBracket": {
      backgroundColor: "#ece7da",
      outline: "1px solid #232323",
      color: "#111111",
    },
    ".cm-nonmatchingBracket": {
      backgroundColor: "#111111",
      color: "#fffdf7",
    },
    ".cm-foldPlaceholder": {
      border: "1px solid #d4d0c4",
      backgroundColor: "#f3eee1",
      color: "#545454",
    },
    ".cm-lintRange-error": {
      backgroundImage: "none",
      borderBottom: "2px solid #232323",
    },
    ".cm-status-bar": {
      borderTop: "1px solid #d4d0c4",
      backgroundColor: "#f3eee1",
      color: "#545454",
    },
  }),
];

export const whiteEditorTheme: CustomTheme = {
  backgroundColor: "#fffdf7",
  lighterBgColor: "#f3eee1",
  borderColor: "#d4d0c4",
  foregroundColor: "#111111",
  accentColor: "#111111",
  errorColor: "#232323",
  selectionColor: "#d9d4c7",
  themeExtension: whiteEditorThemeExtension,
};
