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
