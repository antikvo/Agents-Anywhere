import { socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';

export interface RawHttpResponse {
  statusCode: number;
  text: string;
}

interface RawTarget {
  secure: boolean;
  host: string;
  port: number;
  path: string;
}

function parseTarget(url: string): RawTarget | null {
  const schemeEnd: number = url.indexOf('://');
  if (schemeEnd <= 0) {
    return null;
  }
  const scheme: string = url.substring(0, schemeEnd).toLowerCase();
  const rest: string = url.substring(schemeEnd + 3);
  const pathStart: number = rest.indexOf('/');
  const authority: string = pathStart >= 0 ? rest.substring(0, pathStart) : rest;
  const path: string = pathStart >= 0 ? rest.substring(pathStart) : '/';
  const secure: boolean = scheme === 'https';
  let host: string = authority;
  let port: number = secure ? 443 : 80;
  const colon: number = authority.lastIndexOf(':');
  if (colon > 0 && authority.indexOf(']') < 0) {
    host = authority.substring(0, colon);
    port = Number(authority.substring(colon + 1));
  }
  return { secure: secure, host: host, port: port, path: path };
}

function decodeChunks(chunks: Uint8Array[], total: number): string {
  const merged: Uint8Array = new Uint8Array(total);
  let offset: number = 0;
  chunks.forEach((chunk: Uint8Array) => {
    merged.set(chunk, offset);
    offset += chunk.length;
  });
  const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
  return decoder.decodeToString(merged);
}

/**
 * 原生 socket 版 HTTP PATCH。
 *
 * 模拟器运行时（HarmonyOS 6.0.1 / API 21）的 `@ohos.net.http` 不认识 PATCH：
 * `http.RequestMethod.PATCH` 为 undefined，直接传 "PATCH" 会抛 401 Parameter error。
 * 这里用 TCP / TLS socket 手写最小 HTTP/1.1 请求，只覆盖 JSON 小请求场景。
 */
export class RawHttpClient {
  async request(method: string, url: string, token: string, body: string): Promise<RawHttpResponse> {
    const target: RawTarget | null = parseTarget(url);
    if (target === null) {
      throw new Error(`无法解析地址：${url}`);
    }
    const encoder: util.TextEncoder = new util.TextEncoder();
    const bodyLength: number = encoder.encodeInto(body).length;
    const requestText: string = `${method} ${target.path} HTTP/1.1\r\n` +
      `Host: ${target.host}:${target.port}\r\n` +
      `Authorization: Bearer ${token}\r\n` +
      `Accept: application/json\r\n` +
      `Content-Type: application/json\r\n` +
      `Content-Length: ${bodyLength}\r\n` +
      `Connection: close\r\n\r\n` +
      body;
    const raw: string = target.secure ? await this.sendTls(target, requestText) :
      await this.sendTcp(target, requestText);
    return this.parseResponse(raw);
  }

  private async sendTcp(target: RawTarget, requestText: string): Promise<string> {
    const tcp: socket.TCPSocket = socket.constructTCPSocketInstance();
    const chunks: Uint8Array[] = [];
    let total: number = 0;
    let finish: () => void = () => {
    };
    const closed: Promise<void> = new Promise<void>((resolve: () => void) => {
      finish = resolve;
    });
    tcp.on('message', (info: socket.SocketMessageInfo) => {
      const chunk: Uint8Array = new Uint8Array(info.message);
      chunks.push(chunk);
      total += chunk.length;
    });
    tcp.on('close', () => {
      finish();
    });
    tcp.on('error', () => {
      finish();
    });
    await tcp.bind({ address: '0.0.0.0', port: 0 });
    await tcp.connect({
      address: { address: target.host, port: target.port, family: 1 },
      timeout: 10000
    });
    await tcp.send({ data: requestText });
    await Promise.race([
      closed,
      new Promise<void>((resolve: () => void) => {
        setTimeout(resolve, 15000);
      })
    ]);
    await tcp.close();
    return decodeChunks(chunks, total);
  }

  private async sendTls(target: RawTarget, requestText: string): Promise<string> {
    const tls: socket.TLSSocket = socket.constructTLSSocketInstance();
    const chunks: Uint8Array[] = [];
    let total: number = 0;
    let finish: () => void = () => {
    };
    const closed: Promise<void> = new Promise<void>((resolve: () => void) => {
      finish = resolve;
    });
    tls.on('message', (info: socket.SocketMessageInfo) => {
      const chunk: Uint8Array = new Uint8Array(info.message);
      chunks.push(chunk);
      total += chunk.length;
    });
    tls.on('close', () => {
      finish();
    });
    tls.on('error', () => {
      finish();
    });
    await tls.connect({
      address: { address: target.host, port: target.port, family: 1 },
      secureOptions: {},
      ALPNProtocols: ['http/1.1']
    });
    await tls.send(requestText);
    await Promise.race([
      closed,
      new Promise<void>((resolve: () => void) => {
        setTimeout(resolve, 15000);
      })
    ]);
    await tls.close();
    return decodeChunks(chunks, total);
  }

  private parseResponse(raw: string): RawHttpResponse {
    const split: number = raw.indexOf('\r\n\r\n');
    if (split < 0) {
      throw new Error('PATCH 响应格式异常');
    }
    const head: string = raw.substring(0, split);
    let body: string = raw.substring(split + 4);
    const statusLine: string = head.split('\r\n')[0];
    const parts: string[] = statusLine.split(' ');
    const statusCode: number = parts.length > 1 ? Number(parts[1]) : 0;
    if (head.toLowerCase().indexOf('transfer-encoding: chunked') >= 0) {
      body = this.dechunk(body);
    }
    return { statusCode: statusCode, text: body };
  }

  private dechunk(body: string): string {
    let cursor: number = 0;
    let result: string = '';
    while (cursor < body.length) {
      const lineEnd: number = body.indexOf('\r\n', cursor);
      if (lineEnd < 0) {
        break;
      }
      const size: number = parseInt(body.substring(cursor, lineEnd).trim(), 16);
      if (Number.isNaN(size) || size <= 0) {
        break;
      }
      const start: number = lineEnd + 2;
      result += body.substring(start, start + size);
      cursor = start + size + 2;
    }
    return result;
  }
}
