import { z } from "zod";
import { VersionConflictError } from "@/lib/commands/version-conflict";

export class SafeUserError extends Error {
  constructor(readonly userMessage: string, options?: ErrorOptions) {
    super(userMessage, options);
    this.name = "SafeUserError";
  }
}

type ErrorMetadata = { code?: unknown; name?: unknown };

export function safeActionError(
  error: unknown,
  options: {
    operation: string;
    fallback?: string;
    conflict?: string;
    log?: (message: string, metadata: { operation: string; errorType: string; code?: string }) => void;
  },
) {
  if (error instanceof SafeUserError) return error.userMessage;
  if (error instanceof z.ZodError) return "请检查表单内容后重试。";
  if (error instanceof VersionConflictError) {
    return options.conflict ?? "此内容已在另一处更新。你的输入仍保留，请刷新后重试。";
  }
  const metadata = typeof error === "object" && error !== null ? error as ErrorMetadata : {};
  (options.log ?? console.error)("Server action failed", {
    operation: options.operation,
    errorType: error instanceof Error ? error.name : typeof metadata.name === "string" ? metadata.name : typeof error,
    ...(typeof metadata.code === "string" ? { code: metadata.code } : {}),
  });
  return options.fallback ?? "操作未完成，请稍后重试。";
}
