import http from 'node:http';
import { handleRequest } from './app.mjs';
import { hostingPolicy } from './hosting.mjs';
const port = Number(process.env.PORT || 4173);
const hosting = hostingPolicy(process.env, port);
http.createServer(handleRequest).listen(port, hosting.hosted ? '0.0.0.0' : '127.0.0.1', () => console.log(
  hosting.hosted ? 'Agency Signal: hosted server ready' : `Agency Signal: http://127.0.0.1:${port}`
));
