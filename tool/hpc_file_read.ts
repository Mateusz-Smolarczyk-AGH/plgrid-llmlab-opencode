import { tool } from "@opencode-ai/plugin"
import { execFile } from "node:child_process"
import { promisify } from "node:util"
import path from "node:path"

const execFileAsync = promisify(execFile)
const SCRIPT = path.join(__dirname, "hpc_file_read.sh")

export default tool({
  description:
    "Read the contents of a file from an HPC (Slurm) cluster over SFTP. " +
    "Connects over SSH (using an SSH key + signed SSH certificate) to the " +
    "cluster's login node and fetches a single remote file, returning its " +
    "contents. Useful for inspecting job output/error logs, config files, " +
    "or scripts living on the cluster filesystem.",
  args: {
    host: tool.schema
      .string()
      .describe("Cluster login node hostname, e.g. 'ares.cyfronet.pl'. Defaults to env HPC_HOST if omitted.")
      .optional(),
    user: tool.schema
      .string()
      .describe("Cluster username, e.g. 'plgusername'. Defaults to env HPC_USER if omitted.")
      .optional(),
    remotePath: tool.schema
      .string()
      .describe("Absolute or home-relative path to the file on the cluster, e.g. '/net/scratch/people/plgusername/job.out'. or 'job.out"),
    sshCertificate: tool.schema
      .string()
      .describe("SSH certificate file path.")
      .optional(),
    sshKey: tool.schema
      .string()
      .describe("SSH key file path."),
  },
  async execute(args, context) {
    const host = args.host ?? process.env.HPC_HOST ?? ""
    const user = args.user ?? process.env.HPC_USER ?? ""

    if (!user) {
      return "Error reading HPC file: no user provided and HPC_USER is not set."
    }

    if (!host) {
      return "Error reading HPC file: no host provided and HPC_HOST is not set."
    }

    try {
      const { stdout } = await execFileAsync(
        "bash",
        [
          SCRIPT,
          args.sshKey,
          args.sshCertificate ?? "",
          user,
          host,
          args.remotePath,
        ],
        {
          cwd: context.worktree,
          timeout: 30_000,
          env: process.env,
        }
      )

      const header = `File: ${args.remotePath} on ${user}@${host}`

      return [header, "```", stdout, "```"].join("\n")
    } catch (err: any) {
      const stderrText: string | undefined = err.stderr
      const message = stderrText?.trim() || err.message || String(err)
      return `Error reading HPC file '${args.remotePath}' from ${user}@${host}: ${message}`
    }
  },
})
