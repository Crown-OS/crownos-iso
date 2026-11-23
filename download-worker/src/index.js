const forwardedRequestHeaders = ["Range", "If-Range", "If-None-Match", "If-Modified-Since"];
const authorizationLifetimeMilliseconds = 20 * 60 * 60 * 1000;
const releasesPage = "https://github.com/Crown-OS/crownos-iso/releases/latest";

let authorization;

async function authorizeAccount(env) {
  const response = await fetch("https://api.backblazeb2.com/b2api/v3/b2_authorize_account", {
    headers: { Authorization: `Basic ${btoa(`${env.B2_KEY_ID}:${env.B2_APPLICATION_KEY}`)}` },
  });
  if (!response.ok) throw new Error(`b2_authorize_account returned ${response.status}`);
  const account = await response.json();
  return {
    token: account.authorizationToken,
    bucketFileUrl: `${account.apiInfo.storageApi.downloadUrl}/file/${account.apiInfo.storageApi.bucketName}`,
    expiresAt: Date.now() + authorizationLifetimeMilliseconds,
  };
}

async function fetchFromBucket(request, env, fileName, isRetry = false) {
  if (!authorization || authorization.expiresAt < Date.now()) {
    authorization = await authorizeAccount(env);
  }
  const headers = new Headers({ Authorization: authorization.token });
  for (const name of forwardedRequestHeaders) {
    const value = request.headers.get(name);
    if (value) headers.set(name, value);
  }
  const response = await fetch(`${authorization.bucketFileUrl}/${fileName}`, { method: request.method, headers });
  if (response.status === 401 && !isRetry) {
    authorization = undefined;
    return fetchFromBucket(request, env, fileName, true);
  }
  return response;
}

export default {
  async fetch(request, env) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response(null, { status: 405, headers: { Allow: "GET, HEAD" } });
    }
    const fileName = new URL(request.url).pathname.slice(1);
    if (!fileName) return Response.redirect(releasesPage, 302);
    if (fileName.includes("/")) return new Response("Not found\n", { status: 404 });

    const bucketResponse = await fetchFromBucket(request, env, fileName);
    if (bucketResponse.status === 404) return new Response("Not found\n", { status: 404 });
    const response = new Response(bucketResponse.body, bucketResponse);
    for (const name of [...response.headers.keys()]) {
      if (name.startsWith("x-bz-")) response.headers.delete(name);
    }
    return response;
  },
};
