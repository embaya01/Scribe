import { describe, expect, it } from "vitest";

import { wordCount } from "./text";

describe("wordCount", () => {
  it("counts whitespace-delimited words", () => {
    expect(wordCount("hello world")).toBe(2);
  });

  it("treats empty or whitespace-only input as zero", () => {
    expect(wordCount("")).toBe(0);
    expect(wordCount("   \n\t ")).toBe(0);
  });

  it("collapses runs of whitespace", () => {
    expect(wordCount("  a   b \n c ")).toBe(3);
  });
});
