# Roblox setup: from this repo to a running game

Two pipes connect this repo to Roblox Studio:

| What            | How it travels                                         | Tool                    |
| --------------- | ------------------------------------------------------ | ----------------------- |
| Lua code        | files in `roblox/src/` sync live into Studio            | Rojo 7.7.0              |
| Images          | uploaded once, referenced by asset id in `Sprites.lua`  | Open Cloud API (or manual) |

Roblox cannot load an image from a file or a URL. Every image must be uploaded to Roblox and gets an
**asset id**. The pipeline packs all your sprites into one sheet, uploads it, and writes the id into
`roblox/src/shared/Sprites.lua`. Rojo syncs that file into Studio. That's the whole trick.

## 1. Install Node and the tool

```bash
# Node 20 or newer: https://nodejs.org
git clone https://github.com/DanielSaanu/Rotag
cd Rotag
npm install
npm start            # opens http://localhost:4242
```

`npx warehouse help` lists every command. On Windows use PowerShell or Git Bash, everything is plain Node.

## 2. Install Rojo 7.7.0

Release page: https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0

**Option A, Rokit (recommended, pins the version from `rokit.toml`):**

1. Install Rokit: https://github.com/rojo-rbx/rokit#installation
2. In the repo root run `rokit install`. That installs Rojo 7.7.0 for this folder.

**Option B, download the binary** from the release page for your OS and put it on your PATH (or drop `rojo.exe`
in the repo root; it is gitignored).

Then, once:

```bash
rojo plugin install        # installs the Studio plugin
```

## 3. Connect Studio

1. Open Roblox Studio, create a new **Baseplate** place (or open your game). Save it to Roblox (File > Publish).
2. In the repo root run:
   ```bash
   rojo serve roblox/default.project.json
   ```
3. In Studio: **Plugins** tab > **Rojo** > **Connect** (default address `localhost:34872`).
4. Studio now mirrors `roblox/src/`. Edit a Lua file here, it updates in Studio instantly. **It does not update a
   Play session that is already running**: stop Play, start Play (→ learnings T2).

What the project puts where:

| Repo file                             | Studio location                                     |
| ------------------------------------- | --------------------------------------------------- |
| `roblox/src/shared/*.lua`             | `ReplicatedStorage.Shared` (ModuleScripts)          |
| `roblox/src/client/Client.client.lua` | `StarterPlayer.StarterPlayerScripts.Client`         |
| `roblox/src/server/Server.server.lua` | `ServerScriptService.Server`                        |
| (project file)                        | `ReplicatedStorage.Remotes` (Folder; every RemoteEvent is declared here, never in code) |

Press **Play**. Today's scaffold prints `[Rotag] server up` and `[Rotag] client up` in Output and puts one runner
sprite top-left. If that sprite is blank, the sprite sheet has not been uploaded yet: continue below.

## 4. Make an Open Cloud API key (about two minutes)

1. Go to https://create.roblox.com/dashboard/credentials (Creator Hub > Open Cloud > API Keys).
2. Click **Create API Key**.
3. Name: `rotag`.
4. Under **Access Permissions**, click **Select API System** and choose **Assets**.
   Tick both operations: **Read** and **Write**.
5. Under **Security**:
   - **Accepted IP Addresses**: add `0.0.0.0/0` while developing (any IP). Tighten later if you want.
   - **Expiration**: pick a date or "No Expiration".
6. Click **Save & Generate Key**, then **Copy Key To Clipboard**. You only see it once.
7. Find your **user id**: open your profile on roblox.com. The URL looks like
   `https://www.roblox.com/users/123456789/profile`. The number is your id.
   (If the game belongs to a group, use the group id from the group URL instead.)
8. In the repo root, copy `.env.example` to `.env` and fill in:
   ```
   ROBLOX_API_KEY=paste-the-key-here
   ROBLOX_CREATOR_USER_ID=123456789
   ```
   `.env` is ignored by git. Never commit it, never paste the key into chat.

## 5. Build and upload the sprite sheet

```bash
npx warehouse roblox build --upload
```

This renders every scene in `scenes/` (except ones with `"export": false` or excluded in
`roblox/sheet.json`), packs them into `exports/roblox/sheet_0.png`, uploads it as a Decal, waits for the
asset id, and rewrites `roblox/src/shared/Sprites.lua`. Rojo pushes the new module into Studio. Stop and
re-Play the game and the art is live.

Unchanged sheets are not re-uploaded (hash stored in `roblox/assets.lock.json`). Every changed sprite means a
new upload and a new id; that is normal.

After an upload, commit the two files that now carry the asset id so the repo (and Claude) know about it:

```bash
git add roblox/src/shared/Sprites.lua roblox/assets.lock.json
git commit -m "Record uploaded sprite sheet asset id"
git push
```

**Manual alternative** if you do not want an API key yet:

1. `npx warehouse roblox build` (no upload). It writes `exports/roblox/sheet_0.png`.
2. Upload that PNG at https://create.roblox.com/dashboard/creations > **Development Items** > **Decals** > **Upload Asset**.
3. Copy the id from the new decal's URL and run `npx warehouse roblox setid 0 <id>`.

## 6. Using sprites in Lua

```lua
local Sprites = require(ReplicatedStorage.Shared.Sprites)
local img = Sprites.New("runner_idle", someFrame)   -- new ImageLabel showing the sprite
Sprites.Apply(existingImageLabel, "runner_run_1")   -- or repoint an existing one (this is how a frame changes)
```

Every sprite is a named entry: the scene file name in `scenes/` is the sprite name. Pixels stay crisp because
`Apply` sets `ResampleMode = Pixelated`. How this becomes a side-on world over 3D parts, and how animation works:
[`systems/sprites-and-animation.md`](systems/sprites-and-animation.md).

## 7. After any sprite change (the routine, every time)

```
npx warehouse roblox build --upload
```

Take the decal id it prints, then in the Studio command bar:

```lua
local d = game:GetObjects("rbxassetid://<decal id>")[1] print(d.Texture)
```

then:

```
npx warehouse roblox setid 0 <the number that printed>
```

and commit `roblox/src/shared/Sprites.lua` and `roblox/assets.lock.json` together. Skipping this does not show
blank sprites — it shows the *wrong* sprites, because every sprite's rectangle in the sheet shifts when one is added.

## Troubleshooting

- **Decal id vs image id (blank sprites, no errors, decal looks fine on Creator Hub).** An Open Cloud upload
  creates a *Decal*; the picture inside it is a separate *Image* asset with a different id, and `ImageLabel.Image`
  needs the image id. Roblox's web endpoints refuse to reveal it without a logged-in session, so **the game server
  resolves it at startup** (`Sprites.ResolveOnServer` loads the decal with InsertService and reads the texture id;
  the Output window prints `[Sprites] sheet 1: decal ... -> image ...`) and should send clients the resolved ids.
  If that line is missing or warns, fall back by hand with step 7. `npx warehouse roblox resolve <decal id>` shows
  what the web endpoints answer, for the curious.
- **Images show as blank for a minute after upload**: Roblox moderates images. Wait, then re-Play.
- **`Roblox upload failed 401/403`**: wrong key, key expired, IP restriction, or the Assets API system is missing
  Write permission. Regenerate the key with step 4.
- **`403 ... creator`**: the creator id in `.env` is not you (or you are not a member of the group with asset permissions).
- **Sheet bigger than 1024**: Roblox caps images at 1024x1024. The packer automatically starts `sheet_1.png`.
- **Rojo says "no project file"**: run it from the repo root with the explicit path shown in step 3.
- **Studio DataStores later** (session scores, cosmetics): Game Settings > Security > **Enable Studio Access to
  API Services**, and gate every store open behind a dev-mode flag read once at boot (→ learnings N1).

## Publishing, when it is time

1. **Studio → File → Publish to Roblox.**
2. **Creator Dashboard → the place → Settings → Playability → Public.** Nothing else makes it joinable.

Rojo is a dev-time cable only. Nothing in `roblox/src/` talks to a dev machine, so once published Roblox hosts it.
Code changes need a re-publish, and servers already running keep the old build until they shut down. Before each
publish re-check `library/index.json`: every CC-BY asset in the sheet needs a credit line on the game page.
