# escape=`
# abaplint SCI server as a WINDOWS container, for Docker hosts in Windows container mode
# (for example a Windows Server 2022 build agent, build 20348).
# The abaplint project's own image abaplint/abaplint-backend exists for linux/amd64 only.
#
# Build:  docker build -t abaplint-sci-windows .
# Run:    docker run -d --name abaplint-sci --restart unless-stopped -p 3000:3000 abaplint-sci-windows
# Check:  http://localhost:3000  and  http://localhost:3000/api/v1/ping
#
# Same server code and dependency versions as upstream (package-lock.json of the tag/branch below).

FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Node.js LTS (Node 22 was used when this file was written) and the server source.
ARG NODE_VERSION=22.18.0
ARG SERVER_REF=main
# The server's own lock file brings an older abaplint (2.113.114 when this file was written),
# which misreads screen flow logic and newer 7.40 statements. Pin the abaplint version you
# want here; after the build, /api/v1/ping responds "abaplint version = <ABAPLINT_VERSION>".
ARG ABAPLINT_VERSION=2.120.67

RUN Invoke-WebRequest "https://nodejs.org/dist/v$env:NODE_VERSION/node-v$env:NODE_VERSION-win-x64.zip" -OutFile C:\node.zip ; `
    Expand-Archive C:\node.zip C:\ ; `
    Rename-Item "C:\node-v$env:NODE_VERSION-win-x64" C:\nodejs ; `
    Remove-Item C:\node.zip

ENV PATH="C:\nodejs;C:\Windows\system32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0"

WORKDIR C:\app

RUN Invoke-WebRequest "https://github.com/abaplint/abaplint-sci-server/archive/refs/heads/$env:SERVER_REF.zip" -OutFile C:\src.zip ; `
    Expand-Archive C:\src.zip C:\src ; `
    Copy-Item "C:\src\abaplint-sci-server-$env:SERVER_REF\*" C:\app -Recurse ; `
    Remove-Item C:\src.zip, C:\src -Recurse -Force

# Upstream "npm run build" uses the Unix "cp", so the two steps are done here.
RUN npm ci --no-audit --no-fund ; if ($LASTEXITCODE) { exit $LASTEXITCODE } ; `
    npm install --no-audit --no-fund "@abaplint/core@$env:ABAPLINT_VERSION" ; if ($LASTEXITCODE) { exit $LASTEXITCODE } ; `
    npx tsc ; if ($LASTEXITCODE) { exit $LASTEXITCODE } ; `
    Copy-Item C:\app\public C:\app\build\public -Recurse

ENV PORT=3000 NODE_ENV=production ALB_SUPPRESS_FRONPAGE_LOG=1
EXPOSE 3000

CMD ["node", "build/index.js"]
