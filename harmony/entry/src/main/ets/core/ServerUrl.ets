/**
 * 服务器地址与 API 路径处理。
 *
 * 行为对齐 Android 的 api/ApiUrls.kt：
 * - 只接受 http(s) origin，不允许 userinfo / query / fragment；
 * - 允许地址里带 /api/v2 后缀，其余路径拒绝；
 * - 没有 scheme 时按主机推断：本地网络与带端口的地址用 http，其余用 https。
 *
 * 这里手工解析而不是依赖 @ohos.url：地址格式固定且简单，手工解析在模拟器与真机上
 * 行为一致，也避免 URL 实现在空字段上的差异。
 */
const API_NAMESPACE: string = '/api/v2';

export function apiPath(path: string): string {
  const normalized: string = path.startsWith('/') ? path : '/' + path;
  if (normalized === API_NAMESPACE || normalized.startsWith(API_NAMESPACE + '/')) {
    return normalized;
  }
  return API_NAMESPACE + normalized;
}

export function apiUrl(serverUrl: string, path: string): string {
  const origin: string | null = normalizeServerOrigin(serverUrl);
  if (origin === null) {
    throw new Error('Server URL must be an HTTP(S) origin.');
  }
  return origin + apiPath(path);
}

export function webSocketUrl(serverUrl: string, path: string): string {
  const httpUrl: string = apiUrl(serverUrl, path);
  if (httpUrl.startsWith('https://')) {
    return 'wss://' + httpUrl.substring('https://'.length);
  }
  return 'ws://' + httpUrl.substring('http://'.length);
}

export function usesLocalNetworkHost(host: string): boolean {
  if (host === 'localhost' || host === '0.0.0.0') {
    return true;
  }
  const parts: string[] = host.split('.');
  if (parts.length !== 4) {
    return false;
  }
  const octets: number[] = [];
  for (let i = 0; i < parts.length; i++) {
    const value: number = Number(parts[i]);
    if (!Number.isInteger(value) || value < 0 || value > 255) {
      return false;
    }
    octets.push(value);
  }
  if (octets[0] === 10 || octets[0] === 127) {
    return true;
  }
  if (octets[0] === 192 && octets[1] === 168) {
    return true;
  }
  if (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) {
    return true;
  }
  return false;
}

/**
 * 把用户输入规范化为 origin；非法输入返回 null。
 */
export function normalizeServerOrigin(serverUrl: string): string | null {
  let trimmed: string = serverUrl.trim();
  while (trimmed.length > 0 && trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  if (trimmed.length === 0) {
    return null;
  }

  let scheme: string = '';
  let remainder: string = '';
  const schemeIndex: number = trimmed.indexOf('://');
  if (schemeIndex >= 0) {
    scheme = trimmed.substring(0, schemeIndex).toLowerCase();
    remainder = trimmed.substring(schemeIndex + 3);
  } else {
    const hostPart: string = trimmed.split('/')[0];
    const host: string = hostPart.split(':')[0].toLowerCase();
    if (host.length === 0) {
      return null;
    }
    scheme = (usesLocalNetworkHost(host) || hostPart.includes(':')) ? 'http' : 'https';
    remainder = trimmed;
  }
  if (scheme !== 'http' && scheme !== 'https') {
    return null;
  }
  if (remainder.includes('?') || remainder.includes('#') || remainder.includes('@') ||
    remainder.includes('[')) {
    return null;
  }

  const slashIndex: number = remainder.indexOf('/');
  const authority: string = slashIndex >= 0 ? remainder.substring(0, slashIndex) : remainder;
  const path: string = slashIndex >= 0 ? remainder.substring(slashIndex) : '';
  if (authority.length === 0) {
    return null;
  }
  if (path.length > 0 && path !== API_NAMESPACE) {
    return null;
  }

  let host: string = authority;
  let port: string = '';
  const colonIndex: number = authority.lastIndexOf(':');
  if (colonIndex >= 0) {
    if (authority.indexOf(':') !== colonIndex) {
      return null;
    }
    host = authority.substring(0, colonIndex);
    port = authority.substring(colonIndex + 1);
    if (port.length === 0) {
      return null;
    }
    for (let i = 0; i < port.length; i++) {
      const code: number = port.charCodeAt(i);
      if (code < 48 || code > 57) {
        return null;
      }
    }
  }
  host = host.toLowerCase();
  if (host.length === 0) {
    return null;
  }
  return port.length > 0 ? `${scheme}://${host}:${port}` : `${scheme}://${host}`;
}
