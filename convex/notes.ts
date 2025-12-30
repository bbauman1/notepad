import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { getAuthUserId } from "./lib/auth";

export const list = query({
  args: {},
  handler: async (ctx) => {
    const userId = await getAuthUserId(ctx);

    return await ctx.db
      .query("notes")
      .withIndex("by_user_updated", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();
  },
});

export const get = query({
  args: { id: v.id("notes") },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    const note = await ctx.db.get(args.id);

    if (!note) {
      return null;
    }

    // Verify ownership
    if (note.userId !== userId) {
      throw new Error("Unauthorized");
    }

    return note;
  },
});

export const create = mutation({
  args: {
    content: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    const now = Date.now();

    const id = await ctx.db.insert("notes", {
      content: args.content,
      createdTime: now,
      updatedTime: now,
      userId,
    });
    return id;
  },
});

export const update = mutation({
  args: {
    id: v.id("notes"),
    content: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    const note = await ctx.db.get(args.id);

    if (!note) {
      throw new Error("Note not found");
    }

    // Verify ownership
    if (note.userId !== userId) {
      throw new Error("Unauthorized");
    }

    await ctx.db.patch(args.id, {
      content: args.content,
      updatedTime: Date.now(),
    });
  },
});

export const deleteNote = mutation({
  args: { id: v.id("notes") },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    const note = await ctx.db.get(args.id);

    if (!note) {
      throw new Error("Note not found");
    }

    // Verify ownership
    if (note.userId !== userId) {
      throw new Error("Unauthorized");
    }

    await ctx.db.delete(args.id);
  },
});