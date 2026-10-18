/**
 * 比较点分版本号（忽略非数字后缀），返回 -1 / 0 / 1。
 * 无法解析时返回 null。
 */
export function compareVersions(left: string, right: string): number | null {
  const a: string[] = normalize(left);
  const b: string[] = normalize(right);
  if (a.length === 0 || b.length === 0) {
    return null;
  }
  const length: number = Math.max(a.length, b.length);
  for (let i = 0; i < length; i++) {
    const x: number = i < a.length ? Number.parseInt(a[i], 10) : 0;
    const y: number = i < b.length ? Number.parseInt(b[i], 10) : 0;
    if (Number.isNaN(x) || Number.isNaN(y)) {
      return null;
    }
    if (x !== y) {
      return x > y ? 1 : -1;
    }
  }
  return 0;
}

function normalize(value: string): string[] {
  const trimmed: string = value.trim();
  if (trimmed.length === 0) {
    return [];
  }
  return trimmed.split('.');
}
