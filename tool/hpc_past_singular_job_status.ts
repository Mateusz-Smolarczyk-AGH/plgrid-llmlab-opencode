import { tool } from "@opencode-ai/plugin"
import { execFile } from "node:child_process"
import { promisify } from "node:util"
import path from "node:path"

const execFileAsync = promisify(execFile)

const SCRIPT = path.join(__dirname, "slurmrestd.sh")
export default tool({
  description:
    "List the status of past singular HPC (Slurm) job on a cluster. " +
    "Connects over SSH to the cluster's login node and queries slurmrestd for job state " +
    "(PENDING, RUNNING, COMPLETED, FAILED, etc)",
  args: {
    host: tool.schema
      .string()
      .describe("Cluster login node hostname, e.g. 'ares.cyfronet.pl'. Defaults to env HPC_HOST if omitted."),
    user: tool.schema
      .string()
      .describe("Cluster username, e.g. 'plgusername'. Defaults to env HPC_USER if omitted.")
      .optional(),
    jobId: tool.schema
      .string()
      .describe("Job ID to provide the status for."),
    sshCertificate: tool.schema
      .string()
      .describe("SSH certificate file path.")
      .optional(),
    sshKey: tool.schema
      .string()
      .describe("SSH key file path."),
  },
  async execute(args, context) {
    const host = args.host ?? process.env.HPC_HOST ?? "ares.cyfronet.pl"
    const user = args.user ?? process.env.HPC_USER ?? ""

    if (!user) {
      return "Error reading HPC file: no user provided and HPC_USER is not set."
    }

    if (!host) {
      return "Error reading HPC file: no host provided and HPC_HOST is not set."
    }

    const request =
      `GET /slurmdb/v0.0.39/job/${args.jobId} HTTP/1.1`

    const { stdout } = await execFileAsync("bash", [
      SCRIPT,
      args.sshKey,
      args.sshCertificate ?? "",
      user,
      host,
      request,
    ])

    return stdout
  }
})
