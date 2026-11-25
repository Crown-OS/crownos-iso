import { describeBucketFile, fetchFromBucket } from "./bucket.js";
import { serveLargeFile } from "./large-file-delivery.js";
import { pieceLayout } from "./piece-cache.js";

const forwardedRequestHeaders = ["Range", "If-Range", "If-None-Match", "If-Modified-Since"];
const releasesPage = "https://github.com/Crown-OS/crownos-iso/releases/latest";

async function passThrough(request, env, fileName) {
  const headers = {};
  for (const name of forwardedRequestHeaders) {
    const value = request.headers.get(name);
    if (value) headers[name] = value;
  }
  const bucketResponse = await fetchFromBucket(env, fileName, { method: request.method, headers });
  if (bucketResponse.status === 404) return new Response("Not found\n", { status: 404 });
  const response = new Response(bucketResponse.body, bucketResponse);
  for (const name of [...response.headers.keys()]) {
    if (name.startsWith("x-bz-")) response.headers.delete(name);
  }
  return response;
}

export default {
  async fetch(request, env, context) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response(null, { status: 405, headers: { Allow: "GET, HEAD" } });
    }
    const fileName = new URL(request.url).pathname.slice(1);
    if (!fileName) return Response.redirect(releasesPage, 302);
    if (fileName.includes("/")) return new Response("Not found\n", { status: 404 });

    const file = await describeBucketFile(env, fileName);
    if (file.status === 404) return new Response("Not found\n", { status: 404 });
    const layout = file.status === 200 ? pieceLayout(file.totalSize) : null;
    if (!layout) return passThrough(request, env, fileName);
    return serveLargeFile(request, env, context, fileName, file, layout);
  },
};
