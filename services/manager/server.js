const http = require('http');
const url = require('url');
const os = require('os');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3005;
const DOCKER_SOCKET = '/var/run/docker.sock';
const OLLAMA_HOST = process.env.OLLAMA_HOST || 'ollama';
const OLLAMA_PORT = process.env.OLLAMA_PORT || 11434;

function getLoadedEnv() {
  const candidates = [
    '/app/.env',
    path.join(__dirname, '../../.env'),
    path.join(process.cwd(), '.env'),
    path.join(__dirname, '.env')
  ];
  const envVars = {};
  for (const p of candidates) {
    if (fs.existsSync(p)) {
      try {
        const content = fs.readFileSync(p, 'utf8');
        for (const line of content.split(/\r?\n/)) {
          const trimmed = line.trim();
          if (!trimmed || trimmed.startsWith('#')) continue;
          const idx = trimmed.indexOf('=');
          if (idx > 0) {
            const k = trimmed.slice(0, idx).trim();
            const v = trimmed.slice(idx + 1).trim();
            envVars[k] = v;
          }
        }
        break;
      } catch (_) {}
    }
  }
  return envVars;
}

const PROTECTED_CONTAINERS = new Set([
  'caddy',
  'postgres',
  'n8n',
  'automation-manager'
]);

let containerStatsCache = {};
let systemStatsCache = {
  cpuPercent: '0.0',
  ramUsedGb: '0.0',
  ramTotalGb: (os.totalmem() / 1024 / 1024 / 1024).toFixed(1),
  ramPercent: '0.0'
};

let lastCpuTimes = null;

function calculateSystemCpu() {
  const cpus = os.cpus();
  let totalIdle = 0, totalTick = 0;
  for (const cpu of cpus) {
    for (const type in cpu.times) {
      totalTick += cpu.times[type];
    }
    totalIdle += cpu.times.idle;
  }
  const avgIdle = totalIdle / cpus.length;
  const avgTotal = totalTick / cpus.length;

  if (lastCpuTimes) {
    const idleDiff = avgIdle - lastCpuTimes.idle;
    const totalDiff = avgTotal - lastCpuTimes.total;
    if (totalDiff > 0) {
      const usage = 100 - (idleDiff / totalDiff * 100);
      systemStatsCache.cpuPercent = Math.max(0, Math.min(100, usage)).toFixed(1);
    }
  }

  lastCpuTimes = { idle: avgIdle, total: avgTotal };

  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = totalMem - freeMem;
  systemStatsCache.ramUsedGb = (usedMem / 1024 / 1024 / 1024).toFixed(1);
  systemStatsCache.ramTotalGb = (totalMem / 1024 / 1024 / 1024).toFixed(1);
  systemStatsCache.ramPercent = ((usedMem / totalMem) * 100).toFixed(1);
}

async function pollContainerStats() {
  calculateSystemCpu();
  try {
    const listRes = await dockerRequest('GET', '/containers/json?filters=' + encodeURIComponent(JSON.stringify({ status: ['running'] })));
    const runningContainers = (listRes.data || []).filter(c => {
      const project = c.Labels && c.Labels['com.docker.compose.project'];
      return project === 'automation';
    });

    for (const c of runningContainers) {
      const name = (c.Names && c.Names[0]) ? c.Names[0].replace(/^\//, '') : '';
      if (!name) continue;

      try {
        const statsRes = await dockerRequest('GET', `/containers/${encodeURIComponent(name)}/stats?stream=false`);
        const stats = statsRes.data;
        if (!stats || !stats.memory_stats) continue;

        const memBytes = stats.memory_stats.usage || 0;
        let memStr = `${(memBytes / 1024 / 1024).toFixed(1)} MB`;
        if (memBytes > 1024 * 1024 * 1024) {
          memStr = `${(memBytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
        }

        let cpuStr = '0.0%';
        if (stats.cpu_stats && stats.precpu_stats) {
          const cpuDelta = (stats.cpu_stats.cpu_usage?.total_usage || 0) - (stats.precpu_stats.cpu_usage?.total_usage || 0);
          const systemDelta = (stats.cpu_stats.system_cpu_usage || 0) - (stats.precpu_stats.system_cpu_usage || 0);
          const numCpus = stats.cpu_stats.online_cpus || stats.cpu_stats.cpu_usage?.percpu_usage?.length || 1;
          if (systemDelta > 0 && cpuDelta > 0) {
            cpuStr = `${((cpuDelta / systemDelta) * numCpus * 100).toFixed(1)}%`;
          }
        }

        containerStatsCache[name] = {
          memory: memStr,
          cpu: cpuStr
        };
      } catch (_) {}
    }
  } catch (_) {}
}

setInterval(pollContainerStats, 3000);
pollContainerStats();

function dockerRequest(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const postData = body ? (typeof body === 'string' ? body : JSON.stringify(body)) : null;
    const options = {
      socketPath: DOCKER_SOCKET,
      path,
      method,
      headers: {
        'Host': 'localhost',
        ...(postData ? {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData)
        } : {})
      }
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        let parsed = data;
        try {
          parsed = JSON.parse(data);
        } catch (_) {}
        resolve({ statusCode: res.statusCode, data: parsed, raw: data });
      });
    });

    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

function streamDockerExec(containerName, command, clientRes) {
  return new Promise(async (resolve, reject) => {
    try {
      // 1. Create exec instance
      const execCreateRes = await dockerRequest('POST', `/containers/${encodeURIComponent(containerName)}/exec`, {
        AttachStdout: true,
        AttachStderr: true,
        Tty: true,
        Cmd: ['sh', '-c', command]
      });

      if (!execCreateRes.data || !execCreateRes.data.Id) {
        throw new Error(execCreateRes.data?.message || 'Failed to create exec instance in container');
      }

      const execId = execCreateRes.data.Id;

      // 2. Start exec and stream output
      const postData = JSON.stringify({ Detach: false, Tty: true });
      const options = {
        socketPath: DOCKER_SOCKET,
        path: `/exec/${execId}/start`,
        method: 'POST',
        headers: {
          'Host': 'localhost',
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData)
        }
      };

      clientRes.writeHead(200, {
        'Content-Type': 'text/plain; charset=utf-8',
        'Transfer-Encoding': 'chunked',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive'
      });

      const execReq = http.request(options, (execRes) => {
        execRes.on('data', (chunk) => {
          clientRes.write(chunk);
        });
        execRes.on('end', () => {
          clientRes.end();
          resolve();
        });
      });

      execReq.on('error', (err) => {
        clientRes.write(`\n[Execution Error]: ${err.message}\n`);
        clientRes.end();
        reject(err);
      });

      execReq.write(postData);
      execReq.end();
    } catch (err) {
      clientRes.writeHead(500, { 'Content-Type': 'application/json' });
      clientRes.end(JSON.stringify({ error: err.message }));
      reject(err);
    }
  });
}

function categorizeContainer(name) {
  if (PROTECTED_CONTAINERS.has(name)) return 'core';
  if (name.includes('supabase') || name.includes('realtime')) return 'supabase';
  if (['ollama', 'docling', 'qdrant', 'neo4j'].includes(name)) return 'ai';
  if (['n8n-runners', 'sandbox-runner-1', 'sandbox-api'].includes(name)) return 'runners';
  if (['crawl4ai', 'searxng'].includes(name)) return 'search_crawl';
  if (['redis', 'redisinsight'].includes(name)) return 'database';
  return 'other';
}

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
  });
  res.end(JSON.stringify(payload));
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  const method = req.method.toUpperCase();

  // CORS preflight
  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    });
    return res.end();
  }

  try {
    // Health Check
    if (pathname === '/api/health' && method === 'GET') {
      return sendJson(res, 200, { status: 'ok', service: 'automation-manager', time: new Date().toISOString() });
    }

    // Live System CPU & RAM Meter
    if (pathname === '/api/system/stats' && method === 'GET') {
      calculateSystemCpu();
      return sendJson(res, 200, systemStatsCache);
    }

    // 1. List all containers
    if (pathname === '/api/containers' && method === 'GET') {
      const dockerRes = await dockerRequest('GET', '/containers/json?all=1');
      if (dockerRes.statusCode !== 200) {
        return sendJson(res, dockerRes.statusCode, { error: dockerRes.data });
      }

      const containers = (dockerRes.data || [])
        .filter(c => {
          const project = c.Labels && c.Labels['com.docker.compose.project'];
          const name = (c.Names && c.Names[0]) ? c.Names[0].replace(/^\//, '') : '';
          return project === 'automation' || PROTECTED_CONTAINERS.has(name);
        })
        .map(c => {
          const name = (c.Names && c.Names[0]) ? c.Names[0].replace(/^\//, '') : c.Id.slice(0, 12);
          return {
            id: c.Id,
            name,
            image: c.Image,
            state: c.State,
            status: c.Status,
            created: c.Created,
            ports: (c.Ports || []).map(p => `${p.PublicPort || ''}${p.PublicPort ? '->' : ''}${p.PrivatePort}/${p.Type}`),
            protected: PROTECTED_CONTAINERS.has(name),
            category: categorizeContainer(name),
            metrics: containerStatsCache[name] || { memory: '0 MB', cpu: '0.0%' }
          };
        });

      return sendJson(res, 200, { containers, system: systemStatsCache });
    }

    // 2. Start container
    if (pathname.match(/^\/api\/containers\/([^/]+)\/start$/) && method === 'POST') {
      const name = pathname.match(/^\/api\/containers\/([^/]+)\/start$/)[1];
      const startRes = await dockerRequest('POST', `/containers/${encodeURIComponent(name)}/start`);
      if (startRes.statusCode === 204 || startRes.statusCode === 304) {
        return sendJson(res, 200, { success: true, message: `Container ${name} started` });
      }
      return sendJson(res, startRes.statusCode || 500, { success: false, error: startRes.data });
    }

    // 3. Stop container
    if (pathname.match(/^\/api\/containers\/([^/]+)\/stop$/) && method === 'POST') {
      const name = pathname.match(/^\/api\/containers\/([^/]+)\/stop$/)[1];
      if (PROTECTED_CONTAINERS.has(name)) {
        return sendJson(res, 403, { success: false, error: `Container ${name} is a protected core service and cannot be stopped from the portal.` });
      }
      const stopRes = await dockerRequest('POST', `/containers/${encodeURIComponent(name)}/stop?t=5`);
      if (stopRes.statusCode === 204 || stopRes.statusCode === 304) {
        return sendJson(res, 200, { success: true, message: `Container ${name} stopped` });
      }
      return sendJson(res, stopRes.statusCode || 500, { success: false, error: stopRes.data });
    }

    // 4. Restart container
    if (pathname.match(/^\/api\/containers\/([^/]+)\/restart$/) && method === 'POST') {
      const name = pathname.match(/^\/api\/containers\/([^/]+)\/restart$/)[1];
      const restartRes = await dockerRequest('POST', `/containers/${encodeURIComponent(name)}/restart?t=5`);
      if (restartRes.statusCode === 204) {
        return sendJson(res, 200, { success: true, message: `Container ${name} restarted` });
      }
      return sendJson(res, restartRes.statusCode || 500, { success: false, error: restartRes.data });
    }

    // 5. Group batch actions
    if (pathname.match(/^\/api\/containers\/group\/([^/]+)$/) && method === 'POST') {
      const action = pathname.match(/^\/api\/containers\/group\/([^/]+)$/)[1];
      const dockerRes = await dockerRequest('GET', '/containers/json?all=1');
      const allContainers = (dockerRes.data || []).map(c => (c.Names && c.Names[0]) ? c.Names[0].replace(/^\//, '') : '');

      let targets = [];
      let doStart = true;

      if (action === 'start-ai') {
        targets = ['ollama', 'docling', 'qdrant', 'neo4j'].filter(n => allContainers.includes(n));
        doStart = true;
      } else if (action === 'stop-ai') {
        targets = ['ollama', 'docling', 'qdrant', 'neo4j'].filter(n => allContainers.includes(n));
        doStart = false;
      } else if (action === 'start-supabase') {
        targets = allContainers.filter(n => (n.includes('supabase') || n.includes('realtime')) && !PROTECTED_CONTAINERS.has(n));
        doStart = true;
      } else if (action === 'stop-supabase') {
        targets = allContainers.filter(n => (n.includes('supabase') || n.includes('realtime')) && !PROTECTED_CONTAINERS.has(n));
        doStart = false;
      } else {
        return sendJson(res, 400, { error: `Unknown group action: ${action}` });
      }

      const results = [];
      for (const t of targets) {
        try {
          if (doStart) {
            await dockerRequest('POST', `/containers/${encodeURIComponent(t)}/start`);
          } else {
            await dockerRequest('POST', `/containers/${encodeURIComponent(t)}/stop?t=3`);
          }
          results.push({ name: t, success: true });
        } catch (e) {
          results.push({ name: t, success: false, error: e.message });
        }
      }

      return sendJson(res, 200, { action, results });
    }

    // 6. Ollama Models API
    if (pathname === '/api/ollama/models' && method === 'GET') {
      const ollamaReq = http.request({
        host: OLLAMA_HOST,
        port: OLLAMA_PORT,
        path: '/api/tags',
        method: 'GET',
        timeout: 3000
      }, (ollamaRes) => {
        let body = '';
        ollamaRes.on('data', chunk => { body += chunk; });
        ollamaRes.on('end', () => {
          try {
            const parsed = JSON.parse(body);
            sendJson(res, 200, { running: true, models: parsed.models || [] });
          } catch (e) {
            sendJson(res, 200, { running: true, models: [], raw: body });
          }
        });
      });

      ollamaReq.on('error', () => {
        sendJson(res, 200, { running: false, models: [], message: 'Ollama service is currently stopped or unreachable.' });
      });
      ollamaReq.end();
      return;
    }

    // 7. Ollama Pull Model (streaming NDJSON)
    if (pathname === '/api/ollama/pull' && method === 'POST') {
      let bodyData = '';
      req.on('data', chunk => { bodyData += chunk; });
      req.on('end', () => {
        let modelName = '';
        try {
          const parsed = JSON.parse(bodyData);
          modelName = parsed.name || parsed.model;
        } catch (_) {}

        if (!modelName) {
          return sendJson(res, 400, { error: 'Model name is required (e.g. {"name": "llama3.2:1b"})' });
        }

        const postPayload = JSON.stringify({ name: modelName, stream: true });
        const pullReq = http.request({
          host: OLLAMA_HOST,
          port: OLLAMA_PORT,
          path: '/api/pull',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postPayload)
          }
        }, (pullRes) => {
          res.writeHead(pullRes.statusCode, {
            'Content-Type': 'application/x-ndjson; charset=utf-8',
            'Cache-Control': 'no-cache',
            'Transfer-Encoding': 'chunked',
            'Access-Control-Allow-Origin': '*'
          });

          pullRes.pipe(res);
        });

        pullReq.on('error', (err) => {
          sendJson(res, 502, { error: `Failed to connect to Ollama: ${err.message}. Is Ollama container running?` });
        });

        pullReq.write(postPayload);
        pullReq.end();
      });
      return;
    }

    // 8. Ollama Delete Model
    if (pathname.match(/^\/api\/ollama\/models\/([^/]+)$/) && method === 'DELETE') {
      const modelName = pathname.match(/^\/api\/ollama\/models\/([^/]+)$/)[1];
      const postPayload = JSON.stringify({ name: decodeURIComponent(modelName) });

      const delReq = http.request({
        host: OLLAMA_HOST,
        port: OLLAMA_PORT,
        path: '/api/delete',
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postPayload)
        }
      }, (delRes) => {
        let b = '';
        delRes.on('data', c => { b += c; });
        delRes.on('end', () => {
          sendJson(res, delRes.statusCode, { success: delRes.statusCode === 200, message: `Model ${modelName} deleted` });
        });
      });

      delReq.on('error', (err) => {
        sendJson(res, 502, { error: `Ollama error: ${err.message}` });
      });

      delReq.write(postPayload);
      delReq.end();
      return;
    }

    // 9. Runner Terminal Exec API
    if (pathname === '/api/runner/exec' && method === 'POST') {
      let bodyData = '';
      req.on('data', chunk => { bodyData += chunk; });
      req.on('end', async () => {
        let target = 'n8n-runners';
        let command = '';

        try {
          const parsed = JSON.parse(bodyData);
          target = parsed.target || 'n8n-runners';
          command = parsed.command || '';
        } catch (_) {}

        if (!command || !command.trim()) {
          return sendJson(res, 400, { error: 'Command string is required' });
        }

        // Target validation
        const allowedTargets = ['n8n-runners', 'sandbox-runner-1', 'n8n', 'ollama'];
        if (!allowedTargets.includes(target)) {
          return sendJson(res, 400, { error: `Target container must be one of: ${allowedTargets.join(', ')}` });
        }

        try {
          await streamDockerExec(target, command, res);
        } catch (e) {
          // Handled inside streamDockerExec
        }
      });
      return;
    }

    // 10. List Documentation files
    if (pathname === '/api/docs/list' && method === 'GET') {
      const docsDir = fs.existsSync('/app/docs') ? '/app/docs' : (fs.existsSync(path.join(__dirname, '../../docs')) ? path.join(__dirname, '../../docs') : path.join(process.cwd(), 'docs'));
      try {
        if (!fs.existsSync(docsDir)) {
          return sendJson(res, 200, { success: true, files: [] });
        }
        const files = fs.readdirSync(docsDir).filter(f => f.endsWith('.md'));
        return sendJson(res, 200, { success: true, files });
      } catch (e) {
        return sendJson(res, 500, { error: e.message });
      }
    }

    // 11. Render Doc with dynamic .env variables injected
    if (pathname === '/api/docs/render' && method === 'GET') {
      const parsedUrl = url.parse(req.url, true);
      const filename = parsedUrl.query.file || 'README.md';
      const safeFilename = path.basename(filename);
      const docsDir = fs.existsSync('/app/docs') ? '/app/docs' : (fs.existsSync(path.join(__dirname, '../../docs')) ? path.join(__dirname, '../../docs') : path.join(process.cwd(), 'docs'));
      const filePath = path.join(docsDir, safeFilename);

      if (!fs.existsSync(filePath)) {
        return sendJson(res, 404, { error: `Documentation file '${safeFilename}' not found.` });
      }

      try {
        let content = fs.readFileSync(filePath, 'utf8');
        const env = getLoadedEnv();

        // Dynamically replace ${VAR_NAME} or ${VAR_NAME:-default} with actual values from .env
        content = content.replace(/\$\{([A-Z0-9_]+)(?::-([^}]+))?\}/g, (match, varName, defVal) => {
          if (env[varName] !== undefined && env[varName] !== '') {
            return env[varName];
          }
          return defVal !== undefined ? defVal : match;
        });

        return sendJson(res, 200, {
          success: true,
          file: safeFilename,
          content
        });
      } catch (e) {
        return sendJson(res, 500, { error: e.message });
      }
    }

    // 12. Get Environment Variables dynamically
    if (pathname === '/api/env' && method === 'GET') {
      try {
        const env = getLoadedEnv();
        return sendJson(res, 200, { success: true, env });
      } catch (e) {
        return sendJson(res, 500, { error: e.message });
      }
    }

    // Default 404
    sendJson(res, 404, { error: 'Not Found' });
  } catch (err) {
    sendJson(res, 500, { error: err.message, stack: err.stack });
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Automation Manager daemon listening on port ${PORT}`);
});
