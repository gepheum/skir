import { expect } from "buckwheat";
import { describe, it } from "mocha";
import { parseCommandLine } from "./command_line_parser.js";

describe("command_line_parser", () => {
  describe("parseCommandLine", () => {
    describe("gen command", () => {
      it("should parse basic gen command", () => {
        const result = parseCommandLine(["gen"]);
        expect(result).toMatch({ kind: "gen" });
      });

      it("should parse gen with --root option", () => {
        const result = parseCommandLine(["gen", "--root", "path/to/dir"]);
        expect(result).toMatch({
          kind: "gen",
          root: "path/to/dir",
        });
      });

      it("should parse gen with -r option", () => {
        const result = parseCommandLine(["gen", "-r", "path/to/dir"]);
        expect(result).toMatch({
          kind: "gen",
          root: "path/to/dir",
        });
      });

      it("should parse gen with --root=value syntax", () => {
        const result = parseCommandLine(["gen", "--root=path/to/dir"]);
        expect(result).toMatch({
          kind: "gen",
          root: "path/to/dir",
        });
      });

      it("should parse gen with -r=value syntax", () => {
        const result = parseCommandLine(["gen", "-r=path/to/dir"]);
        expect(result).toMatch({
          kind: "gen",
          root: "path/to/dir",
        });
      });

      it("should parse gen with --watch option", () => {
        const result = parseCommandLine(["gen", "--watch"]);
        expect(result).toMatch({
          kind: "gen",
          subcommand: "watch",
        });
      });

      it("should parse gen with -w option", () => {
        const result = parseCommandLine(["gen", "-w"]);
        expect(result).toMatch({
          kind: "gen",
          subcommand: "watch",
        });
      });

      it("should parse gen with --watch and --root option", () => {
        const result = parseCommandLine([
          "gen",
          "--watch",
          "--root",
          "path/to/dir",
        ]);
        expect(result).toMatch({
          kind: "gen",
          root: "path/to/dir",
          subcommand: "watch",
        });
      });

      it("should parse gen with -w and -r option", () => {
        const result = parseCommandLine(["gen", "-w", "-r", "path/to/dir"]);
        expect(result).toMatch({
          kind: "gen",
          root: "path/to/dir",
          subcommand: "watch",
        });
      });

      it("should return error if positional argument is used with gen", () => {
        const result = parseCommandLine(["gen", "build"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if unknown option is used", () => {
        const result = parseCommandLine(["gen", "--unknown"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --root is missing value", () => {
        const result = parseCommandLine(["gen", "--root"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --root= is missing value", () => {
        const result = parseCommandLine(["gen", "--root="]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --root is specified multiple times", () => {
        const result = parseCommandLine([
          "gen",
          "--root",
          "path1",
          "--root",
          "path2",
        ]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --root is specified multiple times with = syntax", () => {
        const result = parseCommandLine([
          "gen",
          "--root=path1",
          "--root=path2",
        ]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --root is specified with both syntaxes", () => {
        const result = parseCommandLine([
          "gen",
          "--root",
          "path1",
          "--root=path2",
        ]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --ci is used with gen", () => {
        const result = parseCommandLine(["gen", "--ci"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --dry-run is used with gen", () => {
        const result = parseCommandLine(["gen", "--dry-run"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --view is used with gen", () => {
        const result = parseCommandLine(["gen", "--view"]);
        expect(result).toMatch({ kind: "error" });
      });
    });

    describe("format command", () => {
      it("should parse basic format command", () => {
        const result = parseCommandLine(["format"]);
        expect(result).toMatch({ kind: "format" });
      });

      it("should parse format with --root option", () => {
        const result = parseCommandLine(["format", "--root", "path/to/dir"]);
        expect(result).toMatch({
          kind: "format",
          root: "path/to/dir",
        });
      });

      it("should parse format with -r option", () => {
        const result = parseCommandLine(["format", "-r", "path/to/dir"]);
        expect(result).toMatch({
          kind: "format",
          root: "path/to/dir",
        });
      });

      it("should parse format with --ci option", () => {
        const result = parseCommandLine(["format", "--ci"]);
        expect(result).toMatch({
          kind: "format",
          subcommand: "ci",
        });
      });

      it("should parse format with --ci and --root option", () => {
        const result = parseCommandLine([
          "format",
          "--ci",
          "--root",
          "path/to/dir",
        ]);
        expect(result).toMatch({
          kind: "format",
          root: "path/to/dir",
          subcommand: "ci",
        });
      });

      it("should parse format with --ci and -r option", () => {
        const result = parseCommandLine([
          "format",
          "--ci",
          "-r",
          "path/to/dir",
        ]);
        expect(result).toMatch({
          kind: "format",
          root: "path/to/dir",
          subcommand: "ci",
        });
      });

      it("should return error if positional argument is used with format", () => {
        const result = parseCommandLine(["format", "fix"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if unknown option is used", () => {
        const result = parseCommandLine(["format", "--verbose"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --dry-run is used with format", () => {
        const result = parseCommandLine(["format", "--dry-run"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --watch is used with format", () => {
        const result = parseCommandLine(["format", "--watch"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --view is used with format", () => {
        const result = parseCommandLine(["format", "--view"]);
        expect(result).toMatch({ kind: "error" });
      });
    });

    describe("snapshot command", () => {
      it("should parse basic snapshot command", () => {
        const result = parseCommandLine(["snapshot"]);
        expect(result).toMatch({ kind: "snapshot" });
      });

      it("should parse snapshot with --root option", () => {
        const result = parseCommandLine(["snapshot", "--root", "path/to/dir"]);
        expect(result).toMatch({
          kind: "snapshot",
          root: "path/to/dir",
        });
      });

      it("should parse snapshot with -r option", () => {
        const result = parseCommandLine(["snapshot", "-r", "path/to/dir"]);
        expect(result).toMatch({
          kind: "snapshot",
          root: "path/to/dir",
        });
      });

      it("should return error if positional argument is used with snapshot", () => {
        const result = parseCommandLine(["snapshot", "build"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should parse snapshot with --ci option", () => {
        const result = parseCommandLine(["snapshot", "--ci"]);
        expect(result).toMatch({
          kind: "snapshot",
          subcommand: "ci",
        });
      });

      it("should parse snapshot with --view option", () => {
        const result = parseCommandLine(["snapshot", "--view"]);
        expect(result).toMatch({
          kind: "snapshot",
          subcommand: "view",
        });
      });

      it("should parse snapshot with --ci and --root option", () => {
        const result = parseCommandLine([
          "snapshot",
          "--ci",
          "--root",
          "path/to/dir",
        ]);
        expect(result).toMatch({
          kind: "snapshot",
          root: "path/to/dir",
          subcommand: "ci",
        });
      });

      it("should parse snapshot with --view and -r option", () => {
        const result = parseCommandLine([
          "snapshot",
          "--view",
          "-r",
          "path/to/dir",
        ]);
        expect(result).toMatch({
          kind: "snapshot",
          root: "path/to/dir",
          subcommand: "view",
        });
      });

      it("should return error if both --ci and --view are used with snapshot", () => {
        const result = parseCommandLine(["snapshot", "--ci", "--view"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should parse snapshot with --dry-run option", () => {
        const result = parseCommandLine(["snapshot", "--dry-run"]);
        expect(result).toMatch({
          kind: "snapshot",
          subcommand: "dry-run",
        });
      });

      it("should parse snapshot with --dry-run and --root option", () => {
        const result = parseCommandLine([
          "snapshot",
          "--dry-run",
          "--root",
          "path/to/dir",
        ]);
        expect(result).toMatch({
          kind: "snapshot",
          root: "path/to/dir",
          subcommand: "dry-run",
        });
      });

      it("should return error if both --ci and --dry-run are used with snapshot", () => {
        const result = parseCommandLine(["snapshot", "--ci", "--dry-run"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if both --dry-run and --view are used with snapshot", () => {
        const result = parseCommandLine(["snapshot", "--dry-run", "--view"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if all three options are used with snapshot", () => {
        const result = parseCommandLine([
          "snapshot",
          "--ci",
          "--dry-run",
          "--view",
        ]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --watch is used with snapshot", () => {
        const result = parseCommandLine(["snapshot", "--watch"]);
        expect(result).toMatch({ kind: "error" });
      });
    });

    describe("init command", () => {
      it("should parse basic init command", () => {
        const result = parseCommandLine(["init"]);
        expect(result).toMatch({ kind: "init" });
      });

      it("should parse init with --root option", () => {
        const result = parseCommandLine(["init", "--root", "path/to/dir"]);
        expect(result).toMatch({
          kind: "init",
          root: "path/to/dir",
        });
      });

      it("should parse init with -r option", () => {
        const result = parseCommandLine(["init", "-r", "path/to/dir"]);
        expect(result).toMatch({
          kind: "init",
          root: "path/to/dir",
        });
      });

      it("should return error if positional argument is used with init", () => {
        const result = parseCommandLine(["init", "template"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --watch is used with init", () => {
        const result = parseCommandLine(["init", "--watch"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --dry-run is used with init", () => {
        const result = parseCommandLine(["init", "--dry-run"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --ci is used with init", () => {
        const result = parseCommandLine(["init", "--ci"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --view is used with init", () => {
        const result = parseCommandLine(["init", "--view"]);
        expect(result).toMatch({ kind: "error" });
      });
    });

    describe("help command", () => {
      it("should return help for help command", () => {
        const result = parseCommandLine(["help"]);
        expect(result).toMatch({ kind: "help" });
      });

      it("should return help for --help flag", () => {
        const result = parseCommandLine(["--help"]);
        expect(result).toMatch({ kind: "help" });
      });

      it("should return help for -h flag", () => {
        const result = parseCommandLine(["-h"]);
        expect(result).toMatch({ kind: "help" });
      });
    });

    describe("error cases", () => {
      it("should return help for empty args", () => {
        const result = parseCommandLine([]);
        expect(result).toMatch({ kind: "help" });
      });

      it("should return error for unknown command", () => {
        const result = parseCommandLine(["unknown"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error for unexpected positional argument", () => {
        const result = parseCommandLine(["gen", "--watch", "extra-arg"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error for option with missing value at end", () => {
        const result = parseCommandLine(["format", "-r"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --watch specified multiple times", () => {
        const result = parseCommandLine(["gen", "--watch", "--watch"]);
        expect(result).toMatch({ kind: "error" });
      });

      it("should return error if --ci specified multiple times", () => {
        const result = parseCommandLine(["format", "--ci", "--ci"]);
        expect(result).toMatch({ kind: "error" });
      });
    });

    describe("option order", () => {
      it("should parse options in any order for gen", () => {
        const result1 = parseCommandLine(["gen", "--watch", "--root", "dir"]);
        const result2 = parseCommandLine(["gen", "--root", "dir", "--watch"]);
        expect(result1).toMatch({
          kind: "gen",
          root: "dir",
          subcommand: "watch",
        });
        expect(result2).toMatch({
          kind: "gen",
          root: "dir",
          subcommand: "watch",
        });
      });

      it("should parse options in any order for format", () => {
        const result1 = parseCommandLine(["format", "--ci", "--root", "dir"]);
        const result2 = parseCommandLine(["format", "--root", "dir", "--ci"]);
        expect(result1).toMatch({
          kind: "format",
          root: "dir",
          subcommand: "ci",
        });
        expect(result2).toMatch({
          kind: "format",
          root: "dir",
          subcommand: "ci",
        });
      });
    });
  });
});
