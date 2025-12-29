import * as fs from "fs";
import * as fsPromises from "fs/promises";
import * as paths from "path";

export interface FileReader {
  readTextFile(path: string): string | undefined;
}

export interface FileWriter {
  writeTextFile(path: string, contents: string): void;
}

class RealFileSystem implements FileReader, FileWriter {
  readTextFile(path: string): string | undefined {
    try {
      return fs.readFileSync(path, "utf-8");
    } catch (error) {
      if (
        error &&
        typeof error === "object" &&
        "code" in error &&
        error.code === "ENOENT"
      ) {
        return undefined;
      }
      throw error;
    }
  }

  writeTextFile(path: string, contents: string): void {
    fs.writeFileSync(path, contents, "utf-8");
  }
}

export const REAL_FILE_SYSTEM = new RealFileSystem();

export async function isDirectory(path: string): Promise<boolean> {
  try {
    return (await fsPromises.lstat(path)).isDirectory();
  } catch (_e) {
    return false;
  }
}

export function rewritePathForRendering(path: string): string {
  if (paths.isAbsolute(path) || /^\.{1,2}[/\\]$/.test(path)) {
    return path;
  } else {
    // To make it clear that it's a path, prepend "./"
    return `.${paths.sep}${path}`;
  }
}
