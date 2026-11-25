const authorizationLifetimeMilliseconds = 20 * 60 * 60 * 1000;

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

export async function fetchFromBucket(env, fileName, { method = "GET", headers = {} } = {}, isRetry = false) {
  if (!authorization || authorization.expiresAt < Date.now()) {
    authorization = await authorizeAccount(env);
  }
  const response = await fetch(`${authorization.bucketFileUrl}/${fileName}`, {
    method,
    headers: { ...headers, Authorization: authorization.token },
  });
  if (response.status === 401 && !isRetry) {
    authorization = undefined;
    return fetchFromBucket(env, fileName, { method, headers }, true);
  }
  return response;
}

export async function describeBucketFile(env, fileName) {
  const response = await fetchFromBucket(env, fileName, { headers: { Range: "bytes=0-0" } });
  await response.body?.cancel();
  if (response.status !== 206) return { status: response.status };
  const totalSize = Number(response.headers.get("Content-Range")?.split("/")[1]);
  const fileId = response.headers.get("x-bz-file-id");
  if (!Number.isSafeInteger(totalSize) || !fileId) return { status: 502 };
  return {
    status: 200,
    totalSize,
    fileId,
    contentType: response.headers.get("Content-Type") ?? "application/octet-stream",
    lastModified: response.headers.get("Last-Modified"),
  };
}
