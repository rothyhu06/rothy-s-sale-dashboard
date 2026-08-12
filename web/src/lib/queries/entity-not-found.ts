export class EntityNotFoundError extends Error {
  constructor(readonly entityType: "Knowledge" | "Learning" | "Customer" | "Contact", options?: ErrorOptions) {
    super(`${entityType} not found`, options);
    this.name = "EntityNotFoundError";
  }
}

export function throwDetailRead(error: unknown, entityType: "Knowledge" | "Learning" | "Customer" | "Contact", fallback: string) {
  if (!error) return;
  if (typeof error === "object" && error !== null && ["PGRST116", "P0002"].includes(String((error as { code?: unknown }).code))) {
    throw new EntityNotFoundError(entityType, { cause: error });
  }
  throw new Error(fallback, { cause: error });
}
