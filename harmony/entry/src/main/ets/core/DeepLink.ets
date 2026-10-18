/**
 * 深链解析：支持
 * - agentsanywhere://session/<sessionId>
 * - agentsanywhere://sessions/<sessionId>
 * - https://<host>/sessions/<sessionId>
 * - 任意 URL 上的 ?sessionId=<sessionId>
 */
export function sessionIdFromUri(uri: string): string {
  if (uri.length === 0) {
    return '';
  }
  const queryIndex: number = uri.indexOf('sessionId=');
  if (queryIndex >= 0) {
    const start: number = queryIndex + 'sessionId='.length;
    const amp: number = uri.indexOf('&', start);
    const value: string = amp >= 0 ? uri.substring(start, amp) : uri.substring(start);
    return decodeURIComponent(value);
  }
  let marker: string = '/sessions/';
  let pointer: number = uri.indexOf(marker);
  if (pointer < 0) {
    marker = '/session/';
    pointer = uri.indexOf(marker);
  }
  if (pointer >= 0) {
    const start: number = pointer + marker.length;
    const slash: number = uri.indexOf('/', start);
    const question: number = uri.indexOf('?', start);
    let end: number = uri.length;
    if (slash >= 0) {
      end = Math.min(end, slash);
    }
    if (question >= 0) {
      end = Math.min(end, question);
    }
    return decodeURIComponent(uri.substring(start, end));
  }
  return '';
}

export interface MobileLoginDeepLink {
  userId: string;
  loginToken: string;
  server: string;
}

function queryParam(uri: string, key: string): string {
  const marker: string = `${key}=`;
  const index: number = uri.indexOf(marker);
  if (index < 0) {
    return '';
  }
  const start: number = index + marker.length;
  const amp: number = uri.indexOf('&', start);
  const value: string = amp >= 0 ? uri.substring(start, amp) : uri.substring(start);
  return decodeURIComponent(value);
}

/**
 * 扫码登录深链：agentsanywhere://mobile-login?userId=...&loginToken=...&server=...
 * 对应桌面端二维码里的 userId / loginToken / webUrl。
 */
export function mobileLoginFromUri(uri: string): MobileLoginDeepLink | null {
  if (uri.length === 0 || uri.indexOf('mobile-login') < 0) {
    return null;
  }
  let userId: string = queryParam(uri, 'userId');
  let loginToken: string = queryParam(uri, 'loginToken');
  let server: string = queryParam(uri, 'server');
  if (userId.length === 0 || loginToken.length === 0) {
    // 也支持路径形式：agentsanywhere://session/mobile-login/<userId>/<loginToken>[/<server>]
    const marker: string = 'mobile-login/';
    const index: number = uri.indexOf(marker);
    if (index < 0) {
      return null;
    }
    const rest: string = uri.substring(index + marker.length);
    const segments: string[] = rest.split('/');
    if (segments.length < 2) {
      return null;
    }
    userId = decodeURIComponent(segments[0]);
    loginToken = decodeURIComponent(segments[1]);
    if (segments.length > 2) {
      server = decodeURIComponent(segments.slice(2).join('/'));
    }
  }
  if (userId.length === 0 || loginToken.length === 0) {
    return null;
  }
  return { userId: userId, loginToken: loginToken, server: server };
}
