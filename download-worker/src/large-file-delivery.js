import { fetchFromBucket } from "./bucket.js";
import { requestedByteRange, unsatisfiableRange } from "./byte-range.js";
import { fillPieces, isExpectedBucketSlice, lookUpCachedSlice, piecesCovering } from "./piece-cache.js";

function responseHeaders(file) {
  const headers = new Headers({
    "Accept-Ranges": "bytes",
    "Content-Type": file.contentType,
    ETag: `"${file.fileId}"`,
  });
  if (file.lastModified) headers.set("Last-Modified", file.lastModified);
  return headers;
}

function honouredRange(request, file) {
  const ifRange = request.headers.get("If-Range");
  if (ifRange && ifRange !== `"${file.fileId}"`) return null;
  return requestedByteRange(request.headers.get("Range"), file.totalSize);
}

async function sliceSource(env, fileName, file, piece, cachedSlice) {
  const sliceLength = piece.sliceEnd - piece.sliceStart + 1;
  if (cachedSlice && Number(cachedSlice.headers.get("Content-Length")) === sliceLength) {
    return cachedSlice.body;
  }
  await cachedSlice?.body?.cancel();
  const response = await fetchFromBucket(env, fileName, {
    headers: { Range: `bytes=${piece.sliceStart}-${piece.sliceEnd}` },
  });
  if (isExpectedBucketSlice(response, file, sliceLength)) return response.body;
  await response.body?.cancel();
  throw new Error(`bucket answered ${response.status} for ${fileName} bytes ${piece.sliceStart}-${piece.sliceEnd}`);
}

async function streamPieces(env, fileName, file, pieces, cachedSlices, writable) {
  try {
    for (const [position, piece] of pieces.entries()) {
      const body = await sliceSource(env, fileName, file, piece, cachedSlices[position]);
      cachedSlices[position] = undefined;
      await body.pipeTo(writable, { preventClose: true });
    }
    await writable.close();
  } catch (error) {
    await Promise.all(cachedSlices.map((slice) => slice?.body?.cancel()));
    await writable.abort(error).catch(() => {});
  }
}

export async function serveLargeFile(request, env, context, fileName, file, layout) {
  const headers = responseHeaders(file);
  const range = honouredRange(request, file);
  if (range === unsatisfiableRange) {
    headers.set("Content-Range", `bytes */${file.totalSize}`);
    return new Response(null, { status: 416, headers });
  }
  const { start, end } = range ?? { start: 0, end: file.totalSize - 1 };
  const status = range ? 206 : 200;
  if (range) headers.set("Content-Range", `bytes ${start}-${end}/${file.totalSize}`);
  if (request.method === "HEAD") {
    headers.set("Content-Length", String(end - start + 1));
    return new Response(null, { status, headers });
  }

  const pieces = piecesCovering(layout, start, end);
  const cachedSlices = await Promise.all(pieces.map((piece) => lookUpCachedSlice(request.url, file, layout, piece)));
  const missingPieces = pieces.filter((_, position) => !cachedSlices[position]);
  headers.set("X-Cached-Pieces", `${pieces.length - missingPieces.length}/${pieces.length}`);
  if (missingPieces.length) {
    context.waitUntil(fillPieces(env, request.url, fileName, file, layout, missingPieces));
  }

  const { readable, writable } = new FixedLengthStream(end - start + 1);
  context.waitUntil(streamPieces(env, fileName, file, pieces, cachedSlices, writable));
  return new Response(readable, { status, headers });
}
