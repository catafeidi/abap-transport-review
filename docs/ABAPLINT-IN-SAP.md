# abaplint inside SAP: Code Inspector and ATC (optional)

abaplint runs as a check of Code Inspector (SCI) and ATC. Its findings appear in SE80, ABAP in Eclipse, ATC and at task release, like every other check. This is optional: the review workflow works without it. Two parts:

| Part | What | Where |
|---|---|---|
| abaplint server | Node.js application, Docker image `abaplint/abaplint-backend`, port 3000 | a Docker host |
| abaplint client | ABAP code: the "abaplint" check for Code Inspector | each development system, installed with abapGit as a local package |

When a check runs, the client sends the source of the checked objects and their dependencies to the server; the server responds with the findings. Dependencies are taken from the running SAP system, so SAP tables and classes are known (unlike abaplint on GitHub, which only sees the repository).

**The code leaves SAP.** The server must be yours and internal: never a public abaplint service, and not reachable from the internet.

Sources: <https://github.com/abaplint/abaplint-sci-client> and <https://github.com/abaplint/abaplint-sci-server> (both maintained by the abaplint project). Requirements: SAP_BASIS 7.31 or higher and the abapGit developer version.

## 1. The server

```bash
docker pull abaplint/abaplint-backend
docker run -d --name abaplint-sci \
  --restart unless-stopped \
  -p 3000:3000 \
  -e ALB_SUPPRESS_FRONPAGE_LOG=1 \
  abaplint/abaplint-backend
```

- `--restart unless-stopped` keeps it running after a reboot of the host.
- Check: open `http://<host>:3000` in a browser on the network. The page shows the abaplint version.
- Network: each SAP system must reach `<host>:3000`. Open that port only for your SAP systems, in the firewall of the host or a network security group.
- The server speaks plain HTTP. Inside your network that may be acceptable; if the traffic crosses networks, put a reverse proxy with TLS in front and import its certificate into an SSL client in STRUST.
- Updates: `docker pull` and recreate the container. Pin a version tag instead of `latest` if the rules must not change by surprise.

### A Docker host in Windows container mode

`abaplint/abaplint-backend` exists for `linux/amd64` only ("no matching manifest for windows/amd64"). If your Docker host runs in Windows container mode and must stay there, build the same server as a Windows image with `docker/abaplint-server-windows/Dockerfile` (Windows Server Core 2022, Node.js 22, the server source from GitHub, `@abaplint/core` pinned to a version you choose; the Dockerfile pins one):

```powershell
mkdir C:\abaplint-sci ; cd C:\abaplint-sci      # put the Dockerfile here
docker build -t abaplint-sci-windows .
docker run -d --name abaplint-sci --restart unless-stopped -p 3000:3000 abaplint-sci-windows
New-NetFirewallRule -DisplayName "abaplint SCI server from <system>" -Direction Inbound -Protocol TCP -LocalPort 3000 -RemoteAddress <ip-of-the-sap-system> -Action Allow
```

One firewall rule per SAP system. A browser on another machine gets "connection reset": that is the rule working, not the server failing. Test from the SAP system with report `ZTR_SETUP`.

## 2. The client on the SAP system

1. `ZABAPGIT`, New Online: URL `https://github.com/abaplint/abaplint-sci-client`, package `$ABAPLINT` (local, created on the fly), folder logic Prefix, branch `main`. Pull, activate everything.
2. No transport: the client is a tool of the development system.

## 3. Code Inspector

1. `SCI`, menu Goto, Management of, Tests: tick **abaplint** and save.
2. `SCI`: create a **global** check variant, for example `Z_ABAPLINT`, with the abaplint check. Use the arrow icon of the check to open its configuration.
3. **Configuration:** server URL `http://<host>:3000`, HTTP timeout, SSL ID (only used with https), dependency depth **20**, or 0, which is the client's default of 20. Do not set a low value: the client does not cut the dependencies off at that depth, it ends the check of the object with the finding "Max depth n reached" (priority 1), so with a low value most classes are not checked at all. Report `ZTR_SETUP` writes these values and the package configuration below.
4. **Packages:** the packages that get an abaplint configuration (sub-packages are included). `ZTR_SETUP` writes a configuration for each package you list, with the syntax version you choose (default `v740sp08`). A package that already has a configuration keeps it unless "Replace the configuration of a package that has one" is ticked. A minimal configuration:

```json
{
  "syntax": {
    "version": "v740sp08",
    "errorNamespace": "^(Z|LCL_|LTC_|LIF_|LTD_)"
  },
  "rules": {
    "parser_error": true,
    "check_syntax": true
  }
}
```

`version` is the lowest release your code must run on. The same check can run on GitHub on every pull request (`github-templates/abaplint/`, only files changed by the pull request count). That is the one thing ATC on a recent system cannot check by itself: statements that exist since a later support package activate on a newer system but fail on an older one.

Settings in `ZTR_SETUP`, block "abaplint client (only if it is installed)":

| Field on the screen | Meaning |
|---|---|
| abaplint server, http://host:3000 | the server URL |
| Dependency depth (0 = default 20) | see above |
| Syntax version for new packages | the ABAP release the code must be valid for, default `v740sp08` |
| Packages to configure | the packages that get a configuration |
| Also the Clean ABAP rules (for packages that follow them) | adds the Clean ABAP rule set, see below |
| Replace the configuration of a package that has one | off by default; on: the configuration of the listed packages is overwritten |

## 4. ATC at release

Add the abaplint check to the check variant that ATC runs at release (see [ATC-AT-RELEASE.md](ATC-AT-RELEASE.md)). From then on it runs at every task and request release with the other checks, and its findings show in the ATC result of the release. Start with the findings as information, fix the existing places, then let them block like the other priority 1 and 2 findings.

## What to watch

- If the server is down, the abaplint check fails; the other checks still run. Keep the container on `--restart unless-stopped` and watch the host.
- One server serves every SAP system: only the package configuration differs, plus one firewall rule per system on the server.

## 5. Clean ABAP rules inside SAP (packages that follow them)

The package configuration can hold more than the syntax rules. `github-templates/abaplint-sap-package.json` holds the Clean ABAP rules of the GitHub check (`abaplint-clean.json`) without four that are wrong when the check sees one object alone: `unused_variables` (public constants look unused), `prefer_inline`, `unused_methods` and `unused_types`.

- **Effect:** the developer sees a style finding in Eclipse (Ctrl+Shift+F2) and at the task release, before the push. Every finding of abaplint has priority 1, so with ATC set to stop the release on severe findings a style finding stops the release. GitHub stays the authority.
- **Write it:** report `ZTR_SETUP`, tick "Also the Clean ABAP rules" and "Replace the configuration of a package that has one", enter the packages, tick "Write the settings". Without "Replace" an existing configuration is kept.
- **Back to syntax only:** run the report with the packages and without "Also the Clean ABAP rules", with "Replace" ticked.
- **Not for old code.** The same rules give thousands of findings in code that was written before them (old prefixes, `INSERT ... INTO TABLE`, pragmas, case of keywords). Keep syntax only for such packages; apply the Clean ABAP rules to new packages.
- **Align parameters automatically:** `npx @abaplint/cli@<version> <config> --fix` with a configuration that holds only `align_parameters`.
