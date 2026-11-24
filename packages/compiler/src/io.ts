import * as FileSystem from "fs";
import * as FileSystemPromises from "fs/promises";
import * as Paths from "path";

export interface FileReader {
  readTextFile(path: string): string | undefined;
}

export interface FileWriter {
  writeTextFile(path: string, contents: string): void;
}

export interface AsyncFileReader {
  readTextFileAsync(path: string): Promise<string | undefined>;
}

export interface AsyncFileWriter {
  writeTextFileAsync(path: string, contents: string): Promise<void>;
}

class RealFileSystem
  implements FileReader, FileWriter, AsyncFileReader, AsyncFileWriter
{
  readTextFile(path: string): string | undefined {
    try {
      return FileSystem.readFileSync(path, "utf-8");
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
    FileSystem.writeFileSync(path, contents, "utf-8");
  }

  async readTextFileAsync(path: string): Promise<string | undefined> {
    try {
      return await FileSystemPromises.readFile(path, "utf-8");
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

  async writeTextFileAsync(path: string, contents: string): Promise<void> {
    await FileSystemPromises.writeFile(path, contents, "utf-8");
  }
}

export const REAL_FILE_SYSTEM = new RealFileSystem();

export async function isDirectory(path: string): Promise<boolean> {
  try {
    return (await FileSystemPromises.lstat(path)).isDirectory();
  } catch (_e) {
    return false;
  }
}

export function rewritePathForRendering(path: string): string {
  if (Paths.isAbsolute(path) || /^\.{1,2}[/\\]$/.test(path)) {
    return path;
  } else {
    // To make it clear that it's a path, prepend "./"
    return `.${Paths.sep}${path}`;
  }
}
