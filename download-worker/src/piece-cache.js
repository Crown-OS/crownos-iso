import { fetchFromBucket } from "./bucket.js";

const smallestCachedFileBytes = 128 * 1024 * 1024;
const largestPieceBytes = 505 * 1000 * 1000;
const mostPiecesPerFile = 10;
const pieceAlignmentBytes = 1024 * 1024;
const concurrentPieceFills = 3;

export function pieceLayout(totalSize) {
  if (totalSize < smallestCachedFileBytes) return null;
  const evenPiece = Math.ceil(totalSize / mostPiecesPerFile);
  const pieceSize = Math.ceil(evenPiece / pieceAlignmentBytes) * pieceAlignmentBytes;
  if (pieceSize > largestPieceBytes) return null;
  return { pieceSize, pieceCount: Math.ceil(totalSize / pieceSize), totalSize };
}

export function piecesCovering(layout, start, end) {
  const pieces = [];
  for (let index = Math.floor(start / layout.pieceSize); index * layout.pieceSize <= end; index++) {
    const pieceStart = index * layout.pieceSize;
    const pieceEnd = Math.min(pieceStart + layout.pieceSize, layout.totalSize) - 1;
    pieces.push({
      index,
      pieceStart,
      pieceEnd,
      sliceStart: Math.max(start, pieceStart),
      sliceEnd: Math.min(end, pieceEnd),
    });
  }
  return pieces;
}

function pieceCacheKey(requestUrl, file, layout, index) {
  return new URL(`/__pieces/${file.fileId}/${layout.pieceSize}/${index}`, requestUrl).toString();
}

export function isExpectedBucketSlice(response, file, expectedLength) {
  return (
    response.status === 206 &&
    Number(response.headers.get("Content-Length")) === expectedLength &&
    response.headers.get("x-bz-file-id") === file.fileId
  );
}

export function lookUpCachedSlice(requestUrl, file, layout, piece) {
  const coversWholePiece = piece.sliceStart === piece.pieceStart && piece.sliceEnd === piece.pieceEnd;
  const headers = coversWholePiece
    ? {}
    : { Range: `bytes=${piece.sliceStart - piece.pieceStart}-${piece.sliceEnd - piece.pieceStart}` };
  return caches.default.match(new Request(pieceCacheKey(requestUrl, file, layout, piece.index), { headers }));
}

async function fillPiece(env, requestUrl, fileName, file, layout, piece) {
  const pieceLength = piece.pieceEnd - piece.pieceStart + 1;
  const response = await fetchFromBucket(env, fileName, {
    headers: { Range: `bytes=${piece.pieceStart}-${piece.pieceEnd}` },
  });
  if (!isExpectedBucketSlice(response, file, pieceLength)) {
    await response.body?.cancel();
    console.log(`piece ${piece.index} of ${fileName}: bucket answered ${response.status}`);
    return;
  }
  const { readable, writable } = new FixedLengthStream(pieceLength);
  const cachedResponse = new Response(readable, {
    headers: { "Content-Type": file.contentType, "Cache-Control": "public, max-age=31536000, immutable" },
  });
  await Promise.all([
    response.body.pipeTo(writable),
    caches.default.put(pieceCacheKey(requestUrl, file, layout, piece.index), cachedResponse),
  ]);
  console.log(`piece ${piece.index} of ${fileName}: cached`);
}

export async function fillPieces(env, requestUrl, fileName, file, layout, pieces) {
  const queue = [...pieces];
  const fillNextUntilEmpty = async () => {
    for (let piece = queue.shift(); piece; piece = queue.shift()) {
      await fillPiece(env, requestUrl, fileName, file, layout, piece).catch((error) => {
        console.log(`piece ${piece.index} of ${fileName}: ${error}`);
      });
    }
  };
  await Promise.all(Array.from({ length: Math.min(concurrentPieceFills, queue.length) }, fillNextUntilEmpty));
}
