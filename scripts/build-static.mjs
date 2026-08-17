import { cp, copyFile, mkdir, readdir, rm } from "node:fs/promises";
import { extname, join, resolve } from "node:path";

const projectRoot = resolve(import.meta.dirname, "..");
const outputDirectory = join(projectRoot, "dist");
const publicRootFiles = new Set(["robots.txt", "sitemap.xml"]);
const publicRootExtensions = new Set([".html", ".css", ".js", ".svg"]);
const publicDirectories = ["assets", "downloads", "insights", "public"];

await rm(outputDirectory, { recursive: true, force: true });
await mkdir(outputDirectory, { recursive: true });

const rootEntries = await readdir(projectRoot, { withFileTypes: true });
const rootFiles = rootEntries
  .filter((entry) => entry.isFile())
  .map((entry) => entry.name)
  .filter((name) => publicRootFiles.has(name) || publicRootExtensions.has(extname(name)));

await Promise.all(rootFiles.map((name) => copyFile(
  join(projectRoot, name),
  join(outputDirectory, name)
)));

await Promise.all(publicDirectories.map((directory) => cp(
  join(projectRoot, directory),
  join(outputDirectory, directory),
  { recursive: true }
)));

await rm(join(outputDirectory, "public/assets/pvg-ev/README.md"), { force: true });

console.log(`Built ${rootFiles.length} root files and ${publicDirectories.length} public directories in dist/.`);
