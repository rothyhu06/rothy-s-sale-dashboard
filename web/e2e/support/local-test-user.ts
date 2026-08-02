type TestUser = { id: string; email?: string };

type LocalAdminApi = {
  listUsers(options: { page: number; perPage: number }): Promise<{
    data: { users: TestUser[] };
    error: unknown | null;
  }>;
  updateUserById(
    userId: string,
    attributes: { password: string; email_confirm: boolean },
  ): Promise<{ data: { user: TestUser | null }; error: unknown | null }>;
  createUser(attributes: {
    email: string;
    password: string;
    email_confirm: boolean;
  }): Promise<{ data: { user: TestUser | null }; error: unknown | null }>;
};

export async function ensureDeterministicLocalUser(
  admin: LocalAdminApi,
  email: string,
  password: string,
) {
  const listed = await admin.listUsers({ page: 1, perPage: 1000 });
  if (listed.error) throw new Error("Local E2E user lookup failed");

  const existing = listed.data.users.find((user) => user.email === email);
  const result = existing
    ? await admin.updateUserById(existing.id, { password, email_confirm: true })
    : await admin.createUser({ email, password, email_confirm: true });

  if (result.error || !result.data.user) {
    throw new Error("Local E2E user preparation failed");
  }

  return result.data.user;
}
