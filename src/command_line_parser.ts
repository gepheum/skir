export type ParsedArgs =
  | {
      kind: "gen";
      subcommand?: "watch";
      root?: string;
    }
  | {
      kind: "format";
      subcommand?: "ci";
      root?: string;
    }
  | {
      kind: "snapshot";
      subcommand?: "ci" | "view" | "dry-run";
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
Usage: ${COMMAND_BASE} <command> [options]

Commands:
  init               Initialize a new Skir project in the current directory
  gen                Generate code from .skir files to target languages
  format             Format all .skir files in the source directory
  snapshot           Take a snapshot of the source directory, look for
                       breaking changes since the last snapshot
  help               Display this help message

Options:
  --root, -r <path>  Path to the directory containing the skir.yml file
  --watch, -w        Automatically run code generation when .skir files change
                       (gen only)
  --ci               Fail if code is not properly formatted (format) or if code
                       has changed since the last snapshot (snapshot)
  --dry-run          Look for breaking changes since the last snapshot without
                       taking a new snapshot (snapshot only)
  --view             Display the last snapshot (snapshot only)

Examples:
  ${COMMAND_BASE} init
  ${COMMAND_BASE} gen
  ${COMMAND_BASE} gen --watch
  ${COMMAND_BASE} format --root path/to/root/dir
  ${COMMAND_BASE} format --ci -r path/to/root/dir
  ${COMMAND_BASE} snapshot
  ${COMMAND_BASE} snapshot --ci
  ${COMMAND_BASE} snapshot --dry-run
  ${COMMAND_BASE} snapshot --view --root path/to/root/dir
`;

export class CommandLineParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CommandLineParseError";
  }
}

type ParsedOptions = {
  root?: string;
  watch?: boolean;
  ci?: boolean;
  dryRun?: boolean;
  view?: boolean;
  unknown: string[];
};

function parseOptions(args: string[]): ParsedOptions {
  const options: ParsedOptions = {
    unknown: [],
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (!arg) continue;

    // Check for --option=value syntax
    if (arg.startsWith("--root=") || arg.startsWith("-r=")) {
      const value = arg.substring(arg.indexOf("=") + 1);
      if (!value) {
        throw new CommandLineParseError(
          `Option ${arg.split("=")[0]} requires a value`,
        );
      }
      if (options.root !== undefined) {
        throw new CommandLineParseError(
          `Option ${arg.split("=")[0]} specified multiple times`,
        );
      }
      options.root = value;
    } else if (arg === "--root" || arg === "-r") {
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
    } else if (arg === "--watch" || arg === "-w") {
      if (options.watch) {
        throw new CommandLineParseError(
          `Option ${arg} specified multiple times`,
        );
      }
      options.watch = true;
    } else if (arg === "--ci") {
      if (options.ci) {
        throw new CommandLineParseError(`Option --ci specified multiple times`);
      }
      options.ci = true;
    } else if (arg === "--dry-run") {
      if (options.dryRun) {
        throw new CommandLineParseError(
          `Option --dry-run specified multiple times`,
        );
      }
      options.dryRun = true;
    } else if (arg === "--view") {
      if (options.view) {
        throw new CommandLineParseError(
          `Option --view specified multiple times`,
        );
      }
      options.view = true;
    } else if (arg.startsWith("-")) {
      options.unknown.push(arg);
    } else {
      // Positional argument - not allowed anymore
      throw new CommandLineParseError(`Unexpected argument: ${arg}`);
    }
  }

  return options;
}

function buildGenCommand(options: ParsedOptions): ParsedArgs {
  validateNoUnknownOptions(options, "gen");

  if (options.ci) {
    throw new CommandLineParseError(
      `Option --ci is not valid for 'gen' command`,
    );
  }
  if (options.dryRun) {
    throw new CommandLineParseError(
      `Option --dry-run is not valid for 'gen' command`,
    );
  }
  if (options.view) {
    throw new CommandLineParseError(
      `Option --view is not valid for 'gen' command`,
    );
  }

  return {
    kind: "gen",
    root: options.root,
    subcommand: options.watch ? "watch" : undefined,
  };
}

function buildFormatCommand(options: ParsedOptions): ParsedArgs {
  validateNoUnknownOptions(options, "format");

  if (options.watch) {
    throw new CommandLineParseError(
      `Option --watch is not valid for 'format' command`,
    );
  }
  if (options.dryRun) {
    throw new CommandLineParseError(
      `Option --dry-run is not valid for 'format' command`,
    );
  }
  if (options.view) {
    throw new CommandLineParseError(
      `Option --view is not valid for 'format' command`,
    );
  }

  return {
    kind: "format",
    root: options.root,
    subcommand: options.ci ? "ci" : undefined,
  };
}

function buildSnapshotCommand(options: ParsedOptions): ParsedArgs {
  validateNoUnknownOptions(options, "snapshot");

  if (options.watch) {
    throw new CommandLineParseError(
      `Option --watch is not valid for 'snapshot' command`,
    );
  }

  const activeOptions = [
    options.ci && "--ci",
    options.dryRun && "--dry-run",
    options.view && "--view",
  ].filter(Boolean);

  if (activeOptions.length > 1) {
    throw new CommandLineParseError(
      `Options ${activeOptions.join(" and ")} cannot be used together`,
    );
  }

  return {
    kind: "snapshot",
    root: options.root,
    subcommand: options.ci
      ? "ci"
      : options.dryRun
        ? "dry-run"
        : options.view
          ? "view"
          : undefined,
  };
}

function buildInitCommand(options: ParsedOptions): ParsedArgs {
  validateNoUnknownOptions(options, "init");

  if (options.watch) {
    throw new CommandLineParseError(
      `Option --watch is not valid for 'init' command`,
    );
  }
  if (options.ci) {
    throw new CommandLineParseError(
      `Option --ci is not valid for 'init' command`,
    );
  }
  if (options.dryRun) {
    throw new CommandLineParseError(
      `Option --dry-run is not valid for 'init' command`,
    );
  }
  if (options.view) {
    throw new CommandLineParseError(
      `Option --view is not valid for 'init' command`,
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
