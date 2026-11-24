/** Returns a uint32 hash of the given string. */
export function simpleHash(input: string): number {
  // From https://stackoverflow.com/questions/6122571/simple-non-secure-hash-function-for-javascript
  let hash = 0;
  for (let i = 0; i < input.length; i++) {
    const char = input.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash |= 0;
  }
  // Signed int32 to unsigned int32.
  return hash >>> 0;
}
