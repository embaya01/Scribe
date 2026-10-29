/**
 * Count words in a string. Whitespace-delimited; empty/whitespace-only -> 0.
 * A small, real helper (word count is a natural fit for a document editor)
 * that gives the test suite something genuine to assert against.
 */
export function wordCount(input: string): number {
  const trimmed = input.trim();
  return trimmed === "" ? 0 : trimmed.split(/\s+/).length;
}
