export const unsatisfiableRange = Symbol("unsatisfiable range");

export function requestedByteRange(rangeHeader, totalSize) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader?.trim() ?? "");
  if (!match || (match[1] === "" && match[2] === "")) return null;
  if (match[1] === "") {
    const suffixLength = Number(match[2]);
    if (suffixLength === 0) return unsatisfiableRange;
    return { start: Math.max(0, totalSize - suffixLength), end: totalSize - 1 };
  }
  const start = Number(match[1]);
  const end = match[2] === "" ? totalSize - 1 : Math.min(Number(match[2]), totalSize - 1);
  if (start >= totalSize || start > end) return unsatisfiableRange;
  return { start, end };
}
