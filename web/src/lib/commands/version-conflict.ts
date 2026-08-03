export class VersionConflictError extends Error {
  readonly status = 409 as const;

  constructor(
    readonly entityType: "Knowledge" | "Learning",
    readonly expectedVersion: number,
    options?: ErrorOptions,
  ) {
    super(`${entityType} changed since it was loaded`, options);
    this.name = "VersionConflictError";
  }
}

type DatabaseError = { code?: unknown };

export function throwDomainCommandError(
  error: unknown,
  options: { entityType: "Knowledge" | "Learning"; expectedVersion?: number; fallback: string },
): never {
  if (typeof error === "object" && error !== null && (error as DatabaseError).code === "40001" && options.expectedVersion) {
    throw new VersionConflictError(options.entityType, options.expectedVersion, { cause: error });
  }
  throw new Error(options.fallback, { cause: error });
}
