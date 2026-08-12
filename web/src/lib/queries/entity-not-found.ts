export class EntityNotFoundError extends Error {
  constructor(readonly entityType: "Knowledge" | "Learning", options?: ErrorOptions) {
    super(`${entityType} not found`, options);
    this.name = "EntityNotFoundError";
  }
}

export function throwDetailRead(error: unknown, entityType: "Knowledge" | "Learning", fallback: string) {
  if (!error) return;
  if (typeof error === "object" && error !== null && (error as { code?: unknown }).code === "PGRST116") {
    throw new EntityNotFoundError(entityType, { cause: error });
  }
  throw new Error(fallback, { cause: error });
}
