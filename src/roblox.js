// Roblox Open Cloud: upload an image as a Decal asset, poll the operation, return the asset id.
// Docs: https://create.roblox.com/docs/cloud/reference/Asset
import fs from 'node:fs/promises';
import { loadEnv } from './env.js';

const API = 'https://apis.roblox.com/assets/v1';

export function robloxConfig() {
  loadEnv();
  const key = process.env.ROBLOX_API_KEY;
  const userId = process.env.ROBLOX_CREATOR_USER_ID;
  const groupId = process.env.ROBLOX_CREATOR_GROUP_ID;
  if (!key) throw new Error('ROBLOX_API_KEY missing. See docs/ROBLOX_SETUP.md');
  if (!userId && !groupId) throw new Error('Set ROBLOX_CREATOR_USER_ID or ROBLOX_CREATOR_GROUP_ID in .env');
  return { key, creator: groupId ? { groupId: String(groupId) } : { userId: String(userId) } };
}

/** Upload a PNG buffer. Returns { assetId, operationId }. */
export async function uploadImage(buf, { name, description = 'Uploaded by The Warehouse', assetType = 'Decal' } = {}) {
  const { key, creator } = robloxConfig();
  const form = new FormData();
  form.append('request', JSON.stringify({ assetType, displayName: name.slice(0, 50), description: description.slice(0, 1000), creationContext: { creator } }));
  form.append('fileContent', new Blob([buf], { type: 'image/png' }), name.replace(/[^\w.-]/g, '_') + '.png');
  const res = await fetch(`${API}/assets`, { method: 'POST', headers: { 'x-api-key': key }, body: form });
  const text = await res.text();
  if (!res.ok) throw new Error(`Roblox upload failed ${res.status}: ${text}`);
  const op = JSON.parse(text);
  const operationId = op.operationId || (op.path || '').split('/').pop();
  const assetId = await pollOperation(operationId, key);
  return { assetId, operationId };
}

async function pollOperation(operationId, key, { tries = 20, delayMs = 1500 } = {}) {
  for (let i = 0; i < tries; i++) {
    const res = await fetch(`${API}/operations/${operationId}`, { headers: { 'x-api-key': key } });
    const json = await res.json();
    if (json.done) {
      if (json.error) throw new Error(`Roblox operation error: ${JSON.stringify(json.error)}`);
      const id = json.response?.assetId;
      if (!id) throw new Error(`operation finished without assetId: ${JSON.stringify(json)}`);
      return String(id);
    }
    await new Promise(r => setTimeout(r, delayMs));
  }
  throw new Error(`operation ${operationId} did not finish; check Creator Hub > Development Items > Decals`);
}

/** Pull the image id out of a Decal's XML (the decal wraps a Texture whose url points at the real image asset). */
export function parseImageIdFromDecalXml(xml) {
  const m = String(xml).match(/<Content name="Texture">\s*<url>[^<]*?[?&]id=(\d+)/i) || String(xml).match(/<url>[^<]*?[?&]id=(\d+)/i) || String(xml).match(/rbxassetid:\/\/(\d+)/i);
  return m ? m[1] : null;
}

/**
 * Open Cloud uploads create a Decal. The picture inside it is a separate Image asset with its own id, and
 * ImageLabel.Image needs THAT id (Studio's property panel does this swap for you; scripts do not).
 * Tries the public asset delivery endpoints. Returns { imageId, resolved }; falls back to the decal id.
 */
export async function resolveImageId(decalId, { log = null } = {}) {
  const headers = { 'user-agent': 'the-warehouse/0.1', accept: '*/*' };
  const attempts = [
    ['assetdelivery v1', async () => { const res = await fetch(`https://assetdelivery.roblox.com/v1/asset/?id=${decalId}`, { headers, redirect: 'follow' }); const text = await res.text(); return { status: res.status, ok: res.ok, text }; }],
    ['assetdelivery v2', async () => {
      const res = await fetch(`https://assetdelivery.roblox.com/v2/assetId/${decalId}`, { headers });
      const text = await res.text();
      if (!res.ok) return { status: res.status, ok: false, text };
      const json = JSON.parse(text);
      const loc = json.locations?.[0]?.location || json.location;
      if (!loc) return { status: res.status, ok: false, text };
      const body = await fetch(loc, { headers, redirect: 'follow' });
      return { status: body.status, ok: body.ok, text: await body.text() };
    }],
  ];
  for (const [name, attempt] of attempts) {
    try {
      const r = await attempt();
      const id = r.ok ? parseImageIdFromDecalXml(r.text) : null;
      if (log) log(`  ${name}: HTTP ${r.status}${id ? `, parsed image id ${id}` : ', no image id in body'}: ${r.text.slice(0, 240).replace(/\s+/g, ' ')}`);
      // A body that only echoes the decal id back (an error page) is not a resolution.
      if (id && id !== String(decalId)) return { imageId: id, resolved: true };
    } catch (e) {
      if (log) log(`  ${name}: ${e.message}`);
    }
  }
  return { imageId: String(decalId), resolved: false };
}

export async function uploadFile(file, opts) { return uploadImage(await fs.readFile(file), opts); }
