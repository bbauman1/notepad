import type { QueryCtx, MutationCtx } from "../_generated/server";

/**
 * Helper to get the authenticated user's ID from the context.
 * Throws an error if the user is not authenticated.
 */
export async function getAuthUserId(
  ctx: QueryCtx | MutationCtx
): Promise<string> {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    throw new Error("Unauthenticated");
  }
  return identity.tokenIdentifier;
}
