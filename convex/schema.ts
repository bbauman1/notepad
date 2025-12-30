import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  notes: defineTable({
    content: v.string(),
    createdTime: v.number(),
    updatedTime: v.number(),
    userId: v.string(),
  })
    .index("by_updated_time", ["updatedTime"])
    .index("by_user_updated", ["userId", "updatedTime"]),
});
