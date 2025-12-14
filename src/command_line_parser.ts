export type ParsedArgs =
  | {
      kind: "gen";
      subcommand?: "watch";
      root?: string;
    }
  | {
      kind: "format";
      subcommand?: "check";
      root?: string;
    }
  | {
      kind: "snapshot";
      subcommand?: "check" | "view";
      root?: string;
    }
  | {
      kind: "init";
      root?: string;
    }
  | {
      kind: "help";
      root?: undefined;
    }
  | {
      kind: "error";
      root?: undefined;
    };

/**
 * Parse command-line arguments and return a structured representation.
 *
 * @param args - Array of command-line arguments (typically process.argv.slice(2))
 * @returns ParsedCommandLine object representing the command and its options
 */
export function parseCommandLine(args: string[]): ParsedArgs {
  if (args.length === 0) {
    printHelp();
    return { kind: "help" };
  }

  const command = args[0];

  if (command === "help" || command === "--help" || command === "-h") {
    printHelp();
    return { kind: "help" };
  }

  const validCommands = ["gen", "format", "snapshot", "init"];
  if (!command || !validCommands.includes(command)) {
    printError(`Unknown command: ${command}`);
    printHelp();
    return { kind: "error" };
  }

  try {
    const options = parseOptions(args.slice(1));

    switch (command) {
      case "gen":
        return buildGenCommand(options);
      case "format":
        return buildFormatCommand(options);
      case "snapshot":
        return buildSnapshotCommand(options);
      case "init":
        return buildInitCommand(options);
      default:
        throw new CommandLineParseError(`Unexpected command: ${command}`);
    }
  } catch (error) {
    if (error instanceof CommandLineParseError) {
      printError(error.message);
      return { kind: "error" };
    }
    throw error;
  }
}

const COMMAND_BASE = "npx skir";

const HELP_TEXT = `
Usage: ${COMMAND_BASE} <command> [subcommand] [options]

Commands:
  gen [watch]           Generate code from Skir source files to target languages
                        watch: Automatically regenerate when .skir files change
  format [check]        Format all .skir files in the specified directory
                        check: Fail if code is not properly formatted
  snapshot [check|view] Manage .skir file snapshots for compatibility checking
                        check: Fail if there are breaking changes since last snapshot
                        view: Display the last snapshot
  init                  Initialize a new Skir project with a minimal skir.yml file
  help                  Display this help message

Options:
  --root, -r <path>    Path to the directory containing the skir.yml configuration file

Examples:
  ${COMMAND_BASE} gen
  ${COMMAND_BASE} gen watch
  ${COMMAND_BASE} format --root path/to/root/dir
  ${COMMAND_BASE} format check -r path/to/root/dir
  ${COMMAND_BASE} snapshot
  ${COMMAND_BASE} snapshot check
  ${COMMAND_BASE} snapshot view --root path/to/root/dir
`;

export class CommandLineParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CommandLineParseError";
  }
}

type ParsedOptions = {
  root?: string;
  subcommand?: string;
  unknown: string[];
};

function parseOptions(args: string[]): ParsedOptions {
  const options: ParsedOptions = {
    unknown: [],
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (!arg) continue;

    if (arg === "--root" || arg === "-r") {
      if (i + 1 >= args.length) {
        throw new CommandLineParseError(`Option ${arg} requires a value`);
      }
      if (options.root !== undefined) {
        throw new CommandLineParseError(
          `Option ${arg} specified multiple times`,
        );
      }
      options.root = args[i + 1];
      i++; // Skip the next argument as it's the value
    } else if (arg.startsWith("-")) {
      options.unknown.push(arg);
    } else {
      // Positional argument - treat as subcommand
      if (options.subcommand !== undefined) {
        throw new CommandLineParseError(`Unexpected argument: ${arg}`);
      }
      options.subcommand = arg;
    }
  }

  return options;
}

function buildGenCommand(options: ParsedOptions): ParsedArgs {
  validateNoUnknownOptions(options, "gen");

  if (options.subcommand !== undefined && options.subcommand !== "watch") {
    throw new CommandLineParseError(
      `Unknown subcommand for 'gen': ${options.subcommand}`,
    );
  }

  return {
    kind: "gen",
    root: options.root,
    subcommand: options.subcommand === "watch" ? "watch" : undefined,
  };
}

function buildFormatCommand(options: ParsedOptions): ParsedArgs {
  validateNoUnknownOptions(options, "format");

  if (options.subcommand !== undefined && options.subcommand !== "check") {
    throw new CommandLineParseError(
      `Unknown subcommand for 'format': ${options.subcommand}`,
    );
  }

  return {
    kind: "format",
    root: options.root,
    subcommand: options.subcommand === "check" ? "check" : undefined,
  };
}

function buildSnapshotCommand(options: ParsedOptions): ParsedArgs {
  validateNoUnknownOptions(options, "snapshot");

  if (
    options.subcommand !== undefined &&
    options.subcommand !== "check" &&
    options.subcommand !== "view"
  ) {
    throw new CommandLineParseError(
      `Unknown subcommand for 'snapshot': ${options.subcommand}`,
    );
  }

  return {
    kind: "snapshot",
    root: options.root,
    subcommand:
      options.subcommand === "check" || options.subcommand === "view"
        ? options.subcommand
        : undefined,
  };
}

function buildInitCommand(options: ParsedOptions): ParsedArgs {
  validateNoUnknownOptions(options, "init");

  if (options.subcommand !== undefined) {
    throw new CommandLineParseError(
      `Unknown subcommand for 'init': ${options.subcommand}`,
    );
  }

  return {
    kind: "init",
    root: options.root,
  };
}

function validateNoUnknownOptions(
  options: ParsedOptions,
  command: string,
): void {
  if (options.unknown.length > 0) {
    throw new CommandLineParseError(
      `Unknown option${options.unknown.length > 1 ? "s" : ""} for '${command}': ${options.unknown.join(", ")}`,
    );
  }
}

function printHelp(): void {
  console.log(HELP_TEXT);
}

function printError(message: string): void {
  console.error(`Error: ${message}\n`);
}
