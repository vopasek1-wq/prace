// Falešná "brána pro fotky" pro testy aplikace: spouští skutečný gateway/Code.gs (s mocky Googlu)
// za HTTP serverem, který napodobuje chování Apps Scriptu: POST na /exec odpoví přesměrováním (302)
// na adresu s výsledkem, který se přečte GETem.
//
//   node backend-tests/fake-gateway-server.mjs      # vypíše "PORT <číslo>"
import http from 'node:http';
import {loadGateway} from './gateway-harness.mjs';

const allowed = (process.env.ALLOWED_EMAILS ?? 'a@gmail.com').split(',');
const gw = loadGateway({allowedEmails: allowed});
gw.configure();
// Fotky, které majitel do složky na Disku vložil ručně.
for (let i = 1; i <= 3; i++) {
  gw.addFile({name: `rucni-foto-${i}.jpg`, bytes: Buffer.from(`seed-${i}`), dims: {width: 800, height: 600}});
}

const outputs = new Map();
let counter = 0;

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (url.pathname.startsWith('/echo/')) {
    const body = outputs.get(url.pathname.slice('/echo/'.length));
    if (body === undefined) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, {'content-type': 'application/json; charset=utf-8'});
    res.end(body);
    return;
  }
  if (url.pathname === '/exec') {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const body = req.method === 'POST'
        ? JSON.stringify(gw.call(Buffer.concat(chunks).toString('utf8')))
        : JSON.stringify(gw.doGet());
      const id = String(++counter);
      outputs.set(id, body);
      res.writeHead(302, {Location: `http://${req.headers.host}/echo/${id}`});
      res.end();
    });
    return;
  }
  res.writeHead(404);
  res.end();
});

server.listen(0, '127.0.0.1', () => console.log(`PORT ${server.address().port}`));
