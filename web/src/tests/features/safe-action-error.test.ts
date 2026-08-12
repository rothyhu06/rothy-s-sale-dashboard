import { describe, expect, it, vi } from "vitest";
import { z } from "zod";
import { VersionConflictError } from "@/lib/commands/version-conflict";
import { SafeUserError, safeActionError } from "@/lib/actions/safe-action-error";

describe("safe server-action errors", () => {
  it("maps validation and known user errors without reflecting submitted values", () => {
    const secret = "token=secret-body-value";
    const validation = z.string().min(100).safeParse(secret);
    expect(validation.success).toBe(false);
    expect(safeActionError(validation.error, { operation: "save-knowledge" })).toBe("请检查表单内容后重试。");
    expect(safeActionError(new SafeUserError("请确认转换结构化正文。"), { operation: "save-knowledge" })).toBe("请确认转换结构化正文。");
  });

  it("maps conflicts and generic auth/database/runtime failures to allowlisted copy", () => {
    expect(safeActionError(new VersionConflictError("Knowledge", 1), { operation: "save-knowledge" })).toContain("另一处更新");
    for (const failure of [
      new Error("JWT token abc.def.ghi"),
      { code: "42501", message: "auth user secret@example.com" },
      { code: "23505", details: "SQL insert into private_table" },
    ]) {
      const result = safeActionError(failure, { operation: "save-knowledge", fallback: "知识未能保存，请稍后重试。" });
      expect(result).toBe("知识未能保存，请稍后重试。");
      expect(result).not.toMatch(/abc|secret@example|private_table/i);
    }
  });

  it("logs only sanitized metadata", () => {
    const log = vi.fn();
    safeActionError(Object.assign(new Error("token=secret SQL select *"), { code: "XX000" }), {
      operation: "complete-learning", fallback: "学习未能完成，请稍后重试。", log,
    });
    expect(log).toHaveBeenCalledWith("Server action failed", {
      operation: "complete-learning", errorType: "Error", code: "XX000",
    });
    expect(JSON.stringify(log.mock.calls)).not.toMatch(/secret|select \*/i);
  });
});
